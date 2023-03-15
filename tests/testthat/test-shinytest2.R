test_app("simple-app", filter = "shinytest2")library(shinytest2)

test_that("{shinytest2} recording: main-page", {
  app <- AppDriver$new(variant = platform_variant(), name = "main-page", height = 569, 
      width = 979)
  app$set_inputs(pollutant = c("CO", "NO", "O3", "SO2"))
  app$set_inputs(territory = "New Brunswick (NB)")
  app$set_inputs(city = "Moncton, NB")
  app$set_inputs(date = c("2009-01-01", "2020-12-01"))
  app$set_inputs(date = c("2009-01-01", "2017-01-01"))
  app$set_inputs(pollutant = c("CO", "NO", "NO2", "O3", "SO2"))
  app$set_inputs(pollutant = c("CO", "NO", "NO2", "NOX", "O3", "SO2"))
  app$expect_screenshot()
})
