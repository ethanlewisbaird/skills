# Fixture for the ambient-count provenance check.
skill <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), ".."))
source(file.path(skill, "scripts/check_count_provenance.R"))

set.seed(1448145)
genes <- paste0("G", 1:8); cells <- paste0("C", 1:6)
raw <- matrix(rpois(length(genes) * length(cells), 4), nrow = length(genes),
              dimnames = list(genes, cells))
adjusted <- raw
adjusted[1:2, ] <- pmax(adjusted[1:2, ] - 1, 0)          # ambient genes lose counts
stopifnot(!identical(raw, adjusted))

# The object holds the adjusted counts, with rows and columns reordered and one
# extra cell and gene that the candidates do not have.
object <- adjusted[c(8:1), c(6:1)]
object <- cbind(object, C7 = rpois(length(genes), 4))
object <- rbind(object, G9 = rpois(7, 4))

comparison <- rbind(
  compare_counts(object, raw, "raw"),
  compare_counts(object, adjusted, "adjusted")
)
stopifnot(all(comparison$cells == 6L), all(comparison$genes == 8L))
stopifnot(!comparison$matches[comparison$candidate == "raw"])
stopifnot(comparison$matches[comparison$candidate == "adjusted"])
stopifnot(grepl("^matches adjusted$", provenance_verdict(comparison)))

# A restricted comparison uses only the named cells and genes.
restricted <- compare_counts(object, adjusted, "adjusted", cells = cells[1:3], genes = genes[1:2])
stopifnot(restricted$cells == 3L, restricted$genes == 2L, restricted$matches)

# An object that matches neither candidate is reported as unknown, not attributed.
unrelated <- matrix(rpois(length(genes) * length(cells), 4), nrow = length(genes),
                    dimnames = list(genes, cells))
unrelated[1, 1] <- unrelated[1, 1] + 5
comparison <- rbind(
  compare_counts(unrelated, raw, "raw"),
  compare_counts(unrelated, adjusted, "adjusted")
)
stopifnot(!any(comparison$matches))
stopifnot(grepl("^unknown", provenance_verdict(comparison)))

# Identical candidates are reported as indistinguishable rather than as a match.
same <- rbind(
  compare_counts(adjusted, raw, "raw"),
  compare_counts(adjusted, adjusted, "adjusted")
)
stopifnot(same$matches[2], !same$matches[1])

# Non-integer adjusted counts must not be silently rounded into a match.
fractional <- adjusted; fractional[3, 3] <- fractional[3, 3] + 0.5
stopifnot(!compare_counts(fractional, adjusted, "adjusted")$matches)
stopifnot(compare_counts(fractional, adjusted, "adjusted")$max_absolute_difference == 0.5)

cat("count provenance checks: all passed\n")
