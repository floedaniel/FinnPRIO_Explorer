source(test_path("../../R/search.R"))

df <- data.frame(pest = c("Beta b", "Alpha a", "Gamma g"),
                 eppo_code = c("BETABB", "ALPHAA", NA))

test_that("choices label name + EPPO, value is pest, sorted", {
  ch <- pest_search_choices(df)
  expect_equal(unname(ch), c("Alpha a", "Beta b", "Gamma g"))
  expect_equal(names(ch), c("Alpha a [ALPHAA]", "Beta b [BETABB]", "Gamma g"))
})

test_that("choices treat empty EPPO code like NA and drop duplicate pests", {
  d2 <- data.frame(pest = c("Delta d", "Delta d"), eppo_code = c("", ""))
  expect_equal(pest_search_choices(d2), c("Delta d" = "Delta d"))
})

test_that("flag_searched marks searched pests, empty search marks none", {
  expect_equal(flag_searched(df, "Alpha a")$is_searched, c(FALSE, TRUE, FALSE))
  expect_false(any(flag_searched(df, NULL)$is_searched))
  expect_false(any(flag_searched(df, character(0))$is_searched))
})

test_that("hidden_searched returns searched pests missing from plot", {
  expect_equal(hidden_searched(c("Gamma g", "Alpha a"), c("Alpha a")), "Gamma g")
  expect_equal(hidden_searched(NULL, "Alpha a"), character(0))
})
