context("write_delim")

test_that("strings are only quoted if needed", {
  x <- c("a", ',')

  csv <- format_delim(data.frame(x), delim = ",",col_names = FALSE)
  expect_equal(csv, 'a\n\",\"\n')
  ssv <- format_delim(data.frame(x), delim = " ",col_names = FALSE)
  expect_equal(ssv, 'a\n,\n')
})

test_that("a literal NA is quoted", {
  expect_equal(format_csv(data.frame(x = "NA")), "x\n\"NA\"\n")
})

test_that("na argument modifies how missing values are written", {
  df <- data.frame(x = c(NA, "x", "."), y = c(1, 2, NA))
  expect_equal(format_csv(df, na = "."), "x,y\n.,1\nx,2\n\".\",.\n")
})

test_that("read_delim/csv/tsv and write_delim round trip special chars", {
  x <- c("a", '"', ",", "\n","at\t")

  output <- data.frame(x)
  input <- read_delim(format_delim(output, delim = " "), delim = " ", trim_ws = FALSE, progress = FALSE)
  input_csv <- read_csv(format_delim(output, delim = ","), trim_ws = FALSE, progress = FALSE)
  input_tsv <- read_tsv(format_delim(output, delim = "\t"), trim_ws = FALSE, progress = FALSE)
  expect_equal(input$x, input_csv$x, input_tsv$x,  x)
})

test_that("special floating point values translated to text", {
  df <- data.frame(x = c(NaN, NA, Inf, -Inf))
  expect_equal(format_csv(df), "x\nNaN\nNA\nInf\n-Inf\n")
})

test_that("logical values give long names", {
  df <- data.frame(x = c(NA, FALSE, TRUE))
  expect_equal(format_csv(df), "x\nNA\nFALSE\nTRUE\n")
})

test_that("roundtrip preserved floating point numbers", {
  input <- data.frame(x = runif(100))
  output <- read_delim(format_delim(input, delim = " "), delim = " ", progress = FALSE)

  expect_equal(input$x, output$x)
})

test_that("roundtrip preserves dates and datetimes", {
  x <- as.Date("2010-01-01") + 1:10
  y <- as.POSIXct(x)
  attr(y, "tzone") <- "UTC"

  input <- data.frame(x, y)
  output <- read_delim(format_delim(input, delim = " "), delim = " ", progress = FALSE)

  expect_equal(output$x, x)
  expect_equal(output$y, y)
})

test_that("fails to create file in non-existent directory", {
  expect_warning(expect_error(write_csv(mtcars, file.path(tempdir(), "/x/y")), "cannot open the connection"), "No such file or directory")
})

test_that("write_excel_csv/csv2 includes a byte order mark", {
  tmp <- tempfile()
  on.exit(unlink(tmp))

  tmp2 <- tempfile()
  on.exit(unlink(tmp2))

  write_excel_csv(mtcars, tmp)
  write_excel_csv2(mtcars, tmp2)

  output <- readBin(tmp, "raw", file.info(tmp)$size)
  output2 <- readBin(tmp2, "raw", file.info(tmp2)$size)

  # BOM is there
  expect_equal(output[1:3], charToRaw("\xEF\xBB\xBF"))
  expect_equal(output2[1:3], charToRaw("\xEF\xBB\xBF"))

  # Rest of file also there
  expect_equal(output[4:6], charToRaw("mpg"))
  expect_equal(output2[4:6], charToRaw("mpg"))
})


test_that("does not writes a tailing .0 for whole number doubles", {
  expect_equal(format_tsv(tibble::tibble(x = 1)), "x\n1\n")

  expect_equal(format_tsv(tibble::tibble(x = 0)), "x\n0\n")

  expect_equal(format_tsv(tibble::tibble(x = -1)), "x\n-1\n")

  expect_equal(format_tsv(tibble::tibble(x = 999)), "x\n999\n")

  expect_equal(format_tsv(tibble::tibble(x = -999)), "x\n-999\n")

  expect_equal(format_tsv(tibble::tibble(x = 123456789)), "x\n123456789\n")

  expect_equal(format_tsv(tibble::tibble(x = -123456789)), "x\n-123456789\n")
})

test_that("write_csv can write to compressed files", {
  mt <- read_csv(readr_example("mtcars.csv.bz2"))

  filename <- file.path(tempdir(), "mtcars.csv.bz2")
  on.exit(unlink(filename))
  write_csv(mt, filename)

  expect_true(is_bz2_file(filename))
  expect_equal(mt, read_csv(filename))
})

test_that("write_csv writes large integers without scientific notation #671", {
  x <- data.frame(a = c(60150001022000, 60150001022001))
  filename <- file.path(tempdir(), "test_large_integers.csv")
  on.exit(unlink(filename))
  write_csv(x, filename)
  content <- read_file(filename)
  expect_equal(content, "a\n60150001022000\n60150001022001\n")
})

test_that("write_csv writes large integers without scientific notation up to 1E15 #671", {
  x <- data.frame(a = c(1E13, 1E14, 1E15, 1E16))
  filename <- file.path(tempdir(), "test_large_integers2.csv")
  on.exit(unlink(filename))
  write_csv(x, filename)
  content <- read_file(filename)
  expect_equal(content, "a\n10000000000000\n100000000000000\n1e15\n1e16\n")
  x_exp <- read_csv(filename, col_types = "d")
  expect_equal(x$a, x_exp$a)
})

test_that("write_csv2 and format_csv2 writes ; sep and , decimal mark", {
  df <- tibble::tibble(x = c(0.5, 2, 1.2), y = c("a", "b", "c"))
  expect_equal(format_csv2(df), "x;y\n0,5;a\n2,0;b\n1,2;c\n")

  filename <- tempfile(pattern = "readr", fileext = ".csv")
  on.exit(unlink(filename))
  write_csv2(df, filename)

  expect_equivalent(df, suppressMessages(read_csv2(filename)))
})

test_that("write_csv2 and format_csv2 writes NA appropriately", {
  df <- tibble::tibble(x = c(0.5, NA, 1.2), y = c("a", "b", NA))
  expect_equal(format_csv2(df), "x;y\n0,5;a\nNA;b\n1,2;NA\n")
})

test_that("Can change the escape behavior for quotes", {
  df <- data.frame(x = c("a", '"', ",", "\n"))

  expect_error(format_delim(df, "\t", quote_escape = "invalid"), "should be one of")

  expect_equal(format_delim(df, "\t"), "x\na\n\"\"\"\"\n,\n\"\n\"\n")
  expect_equal(format_delim(df, "\t", quote_escape = "double"), "x\na\n\"\"\"\"\n,\n\"\n\"\n")
  expect_equal(format_delim(df, "\t", quote_escape = "backslash"), "x\na\n\"\\\"\"\n,\n\"\n\"\n")
  expect_equal(format_delim(df, "\t", quote_escape = "none"), "x\na\n\"\"\"\n,\n\"\n\"\n")
  expect_equal(format_delim(df, "\t", quote_escape = FALSE), "x\na\n\"\"\"\n,\n\"\n\"\n")
})

test_that("hms NAs are written without padding (#930)", {
  df <- data.frame(x = hms::as.hms(c(NA, 34.234)))
  expect_equal(format_tsv(df), "x\nNA\n00:00:34.234\n")
})
