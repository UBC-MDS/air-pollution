library(shinytest2)


test_that("{shinytest2} recording: no-change", {
  app <- AppDriver$new(variant = platform_variant(), name = "no-change", height = 569, 
      width = 979, load_timeout = 10e+06)
  app$set_inputs(`plotly_afterplot-A` = "\"stackedBarChart\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_afterplot-A` = "\"linePlot\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":517.5,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":698,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$expect_screenshot()
})


test_that("{shinytest2} recording: change-province", {
  app <- AppDriver$new(variant = platform_variant(), name = "change-province", height = 569, 
      width = 979, load_timeout = 10e+06)
  app$set_inputs(`plotly_afterplot-A` = "\"stackedBarChart\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_afterplot-A` = "\"linePlot\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":517.5,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":698,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(territory = "British Columbia (BC)")
  app$expect_screenshot()
})


test_that("{shinytest2} recording: change-date", {
  app <- AppDriver$new(variant = platform_variant(), name = "change-date", height = 569, 
      width = 979, load_timeout = 1e+07)
  app$set_inputs(`plotly_afterplot-A` = "\"stackedBarChart\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_afterplot-A` = "\"linePlot\"", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":517.5,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(`plotly_relayout-A` = "{\"width\":698,\"height\":400}", allow_no_input_binding_ = TRUE, 
      priority_ = "event")
  app$set_inputs(date = c("2018-01-01", "2020-12-01"))
  app$expect_screenshot()
})
