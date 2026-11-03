# Base-R worker. Source this in R/radian, then call persistent_serve(session_directory).
# The queue loop occupies the interpreter until graceful shutdown or Ctrl-C.
persistent_serve <- function(session, python = Sys.which("python"), initialize = FALSE) {
    session <- normalizePath(session, mustWork = TRUE)
    if (readLines(file.path(session, "language.txt"), warn = FALSE) != "r")
        stop("Session is not configured for R")
    if (exists("persistent_paths", envir = .GlobalEnv, inherits = FALSE))
        stop("The name persistent_paths is reserved; rename it before attaching")
    helper <- readLines(file.path(session, "bridge.txt"), warn = FALSE)
    control <- function(command, ...) {
        arguments <- c(shQuote(helper), command, shQuote(session), shQuote(as.character(c(...))))
        value <- suppressWarnings(system2(python, arguments, stdout = TRUE))
        status <- attr(value, "status")
        if (!is.null(status) && status != 0L)
            stop("Bridge control failed: ", command)
        value
    }
    control("_begin", Sys.getpid())
    previous_wd <- getwd()
    normal_exit <- FALSE
    active <- NULL
    on.exit({
        if (exists("persistent_paths", envir = .GlobalEnv, inherits = FALSE))
            rm("persistent_paths", envir = .GlobalEnv)
        setwd(previous_wd)
        control(if (normal_exit) "_stopped" else "_failed")
    }, add = TRUE)

    run_task <- function(task) {
        output <- file(file.path(task, "stdout.txt"), open = "at")
        errors <- file(file.path(task, "stderr.txt"), open = "at")
        output_depth <- sink.number()
        message_connection <- sink.number(type = "message")
        sink(output)
        sink(errors, type = "message")
        on.exit({
            while (sink.number() > output_depth) sink()
            if (message_connection == 2L) sink(type = "message")
            else sink(message_connection, type = "message")
            close(output)
            close(errors)
        }, add = TRUE)
        tryCatch({
            code <- parse(file.path(task, "code.R"), keep.source = TRUE)
            withCallingHandlers({
                for (expression in code) {
                    answer <- withVisible(eval(expression, envir = .GlobalEnv))
                    if (answer$visible) print(answer$value)
                }
            }, warning = function(w) {
                cat("WARNING: ", conditionMessage(w), "\n", sep = "", file = errors)
                invokeRestart("muffleWarning")
            }, message = function(m) {
                cat("MESSAGE: ", conditionMessage(m), "\n", sep = "", file = errors)
                invokeRestart("muffleMessage")
            })
            "successful"
        }, error = function(e) {
            cat("ERROR: ", conditionMessage(e), "\n", sep = "", file = errors)
            "failed"
        })
    }

    tryCatch({
        setwd(readLines(file.path(session, "project.txt"), warn = FALSE))
        init <- file.path(session, "init.R")
        if (initialize && file.exists(init)) source(init, local = .GlobalEnv)
        runtime <- file.path(session, "runtime.txt")
        writeLines(capture.output(sessionInfo()), runtime)
        Sys.chmod(runtime, "0600")
        control("_ready")
        while (!file.exists(file.path(session, "stop-requested"))) {
            # Avoid spawning a Python helper while the queue is empty.
            queued <- list.dirs(file.path(session, "queue"), recursive = FALSE)
            if (length(queued) == 0L) {
                Sys.sleep(1)
                next
            }
            path <- control("_claim")
            if (length(path) == 0L || !nzchar(path[1L])) next
            active <- path[1L]
            assign("persistent_paths", function(...) {
                paths <- normalizePath(c(...), mustWork = TRUE)
                cat(paste0(paths, "\n"), sep = "", file = file.path(active, "paths.txt"), append = TRUE)
                invisible(paths)
            }, envir = .GlobalEnv)
            setwd(readLines(file.path(active, "cwd.txt"), warn = FALSE))
            outcome <- run_task(active)
            control("_finish", active, outcome)
            active <- NULL
        }
        normal_exit <- TRUE
    }, interrupt = function(e) {
        if (!is.null(active)) control("_finish", active, "failed")
        normal_exit <<- TRUE
    })
    invisible(NULL)
}

if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    persistent_serve(args[1L], python = args[2L], initialize = TRUE)
}
