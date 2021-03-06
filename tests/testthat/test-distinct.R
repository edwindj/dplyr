context("Distinct")

df <- data.frame(
  x = c(1, 1, 1, 1),
  y = c(1, 1, 2, 2),
  z = c(1, 1, 2, 2)
)
tbls <- test_load(df)

test_that("distinct equivalent to local unique", {
  compare_tbls(tbls, function(x) x %>% distinct(), ref = unique(df))
})

test_that("distinct removes duplicates (sql)", {
  expect_error(nrow(distinct(tbls$sqlite, x)), "specified columns")
})

test_that("distinct works for 0-sized columns (#1437)", {
  df <- data_frame(x = 1:10) %>% select(-x)
  ddf <- distinct(df)
  expect_equal( ncol(ddf), 0L )
})
