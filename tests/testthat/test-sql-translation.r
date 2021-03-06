context("SQL translation")

test <- src_sqlite(tempfile(), create = TRUE)

expect_same_in_sql <- function(expr) {
  expr <- substitute(expr)

  sql <- translate_sql_q(list(expr))
  actual <- dbGetQuery(test$con, paste0("SELECT ", sql))[[1]]

  exp <- eval(expr, parent.frame())

  expect_equal(actual, exp, label = deparse(substitute(expr)))
}

test_that("Simple maths is correct", {
  expect_same_in_sql(1 + 2)
  expect_same_in_sql(2 * 4)
  expect_same_in_sql(5 / 10)
  expect_same_in_sql(1 - 10)
  expect_same_in_sql(5 ^ 2)
  expect_same_in_sql(5 ^ 1/2)
  expect_same_in_sql(100 %% 3)
})

test_that("dplyr.strict_sql = TRUE prevents auto conversion", {
  old <- options(dplyr.strict_sql = TRUE)
  on.exit(options(old))

  expect_equal(translate_sql(1 + 2), sql("1.0 + 2.0"))
  expect_error(translate_sql(blah(x)), "could not find function")
})

test_that("Wrong number of arguments raises error", {
  expect_error(translate_sql(mean(1, 2)), "Invalid number of args")
})

test_that("Named arguments generates warning", {
  expect_warning(translate_sql(mean(x = 1)), "Named arguments ignored")
})

test_that("Subsetting always evaluated locally", {
  x <- list(a = 1, b = 1)
  y <- c(2, 1)

  correct <- quote(`_var` == 1)

  expect_equal(partial_eval(quote(`_var` == x$a)), correct)
  expect_equal(partial_eval(quote(`_var` == x[[2]])), correct)
  expect_equal(partial_eval(quote(`_var` == y[2])), correct)
})

test_that("between translated to special form (#503)", {

  out <- translate_sql(between(x, 1, 2))
  expect_equal(out, sql('"x" BETWEEN 1.0 AND 2.0'))
})

test_that("is.na and is.null are equivalent",{
  expect_equal(translate_sql(!is.na(x)), sql('NOT(("x") IS NULL)'))
  expect_equal(translate_sql(!is.null(x)), sql('NOT(("x") IS NULL)'))
})

test_that("if translation adds parens", {
  expect_equal(
    translate_sql(if (x) y),
    sql('CASE WHEN ("x") THEN ("y") END')
  )
  expect_equal(
    translate_sql(if (x) y else z),
    sql('CASE WHEN ("x") THEN ("y") ELSE ("z") END')
  )

})

# Minus -------------------------------------------------------------------

test_that("unary minus flips sign of number", {
  expect_equal(translate_sql(-10), sql(-10))
  expect_equal(translate_sql(x == -10), sql('"x" = -10.0'))
  expect_equal(translate_sql(x %in% c(-1L, 0L)), sql('"x" IN (-1, 0)'))
})

test_that("unary minus wraps non-numeric expressions", {
  expect_equal(translate_sql(-(1L + 2L)), sql("-(1 + 2)"))
  expect_equal(translate_sql(-mean(x)), sql('-AVG("x")'))
})

test_that("binary minus subtracts", {
  expect_equal(translate_sql(1L - 10L), sql("1 - 10"))
})

# Window functions --------------------------------------------------------

test_that("window functions without group have empty over", {
  expect_equal(translate_window_sql(n()), sql("COUNT(*) OVER ()"))
  expect_equal(translate_window_sql(sum(x)), sql('sum("x") OVER ()'))
})

test_that("aggregating window functions ignore order_by", {
  expect_equal(
    translate_window_sql(n(), order_by = "x"),
    sql("COUNT(*) OVER ()")
  )
  expect_equal(
    translate_window_sql(sum(x), order_by = "x"),
    sql('sum("x") OVER ()')
  )

})

test_that("cumulative windows warn if no order", {
  expect_warning(translate_window_sql(cumsum(x)), "does not have explicit order")
  expect_warning(translate_window_sql(cumsum(x), order_by = "x"), NA)
})

test_that("ntile always casts to integer", {
  expect_equal(
    translate_window_sql(ntile(x, 10.5)),
    sql('NTILE(10) OVER (ORDER BY "x")')
  )
})


