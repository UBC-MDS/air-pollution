library(shiny)
library(fmsb)
library(plyr)
library(tidyverse)
library(leaflet)
library(lubridate)

source("config.R")

if (Sys.getenv("PORT") != "") {
  options(shiny.port = as.integer(Sys.getenv("PORT")))
}

globalVariables(c(NAPS_dataset_path))

options(shiny.autoreload = TRUE)

cat("Loading the NAPS dataset. Please wait...")

data <- read_csv(NAPS_dataset_path, show_col_types = FALSE) |>
  mutate(
    Territory_Name = case_when(
      Territory == "AB" ~ "Alberta",
      Territory == "BC" ~ "British Columbia",
      Territory == "MB" ~ "Manitoba",
      Territory == "NB" ~ "New Brunswick",
      Territory == "NL" ~ "Newfoundland",
      Territory == "NS" ~ "Nova Scotia",
      Territory == "NT" ~ "Northwest Territories",
      Territory == "NU" ~ "Nunavut",
      Territory == "ON" ~ "Ontario",
      Territory == "PE" ~ "Prince Edward Island",
      Territory == "QC" ~ "Quebec",
      Territory == "SK" ~ "Saskatchewan",
      Territory == "YU" ~ "Yukon",
      TRUE ~ NA
    )
  ) |>
  mutate_if(is.character, utf8::utf8_encode) |>
  mutate(
    City = paste0(City, ", ", Territory),
    Territory = paste0(Territory_Name, " (", Territory, ")")
  ) |>
  mutate(
    City = fct_relevel(as.factor(City)),
    Province = fct_relevel(as.factor(Territory)),
    Pollutant = fct_relevel(
      as.factor(Pollutant),
      c("CO", "SO2", "NO", "NO2", "NOX", "O3", "PM2.5", "PM10")
    )
  )

cat("Done\n")

# Define UI for application
ui <- fluidPage(
  # Application title
  titlePanel("Dashboard of Pollution Trends across Canada, 2001 - 2020"),
  
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      dateRangeInput(
        "date",
        "Date:",
        min = min(data$Date),
        max = max(data$Date),
        start = min(data$Date),
        end = max(data$Date)
      ),
      selectizeInput(
        "province",
        "Province/Territory:",
        choices = levels(data$Province),
        options = list(placeholder = 'All Provinces/Territories'),
        multiple = TRUE
      ),
      selectizeInput(
        "city",
        "City:",
        choices = levels(data$City),
        options = list(placeholder = 'All Cities'),
        multiple = TRUE
      ),
      checkboxGroupInput(
        "pollutant",
        "Pollutants:",
        choices = levels(data$Pollutant),
        selected = levels(data$Pollutant)
      )
    ),
    mainPanel(tabsetPanel(
      type = "tabs",
      tabPanel(
        "Breakdown of Pollutants",
        fluidRow(column(width = 5, plotOutput("radarPlot")),
                 column(width = 7, plotOutput("stackedBarChart"))),
        fluidRow(column(width = 12, plotOutput("linePlot")))
      ),
      tabPanel("Map", leafletOutput("map"))
    ))
  ),
  HTML(
    "<h5><b>Definitions</b></h5>
         <ul>
          <li>CO: Carbon monoxide</li>
          <li>NO: Nitrogen oxide</li>
          <li>NO2: Nitrogen dioxide</li>
          <li>NOX: Nitrogen oxides </li>
          <li>O3: Ozone</li>
          <li>PM2.5: Particulate matter less than or equal to 2.5 micrometres</li>
          <li>PM10: particulate matter less than or equal to 10 micrometres</li>
          <li>SO2: Sulphur dioxide</li>
         </ul>"
  ),
  hr(),
  HTML(
    '<p><b>Authors:</b> Elena Ganacheva, Ritisha Sharma, Ranjit Sundaramurthi, Kelvin Wong</p>
        <p><b>Attribution:</b>
        <a href="https://www.canada.ca/en/environment-climate-change/services/air-pollution/monitoring-networks-data/national-air-pollution-program.html"
        >The National Air Pollution Surveillance (NAPS) data</a> is published by the Government of Canada,
         under the terms of the Open Government License - Canada.</p>'
  )
)

# Define server logic required
server <- function(input, output, session) {
  # Filters the data based on user selections
  data_selected <- reactive({
    data_filtered <- data |>
      filter(between(Date, input$date[1], input$date[2])) |>
      filter(Pollutant %in% input$pollutant)
    
    if (length(input$province) > 0) {
      data_filtered <- data_filtered |>
        filter(Province %in% input$province)
    }
    
    if (length(input$city) > 0) {
      data_filtered <- data_filtered |>
        filter(City %in% input$city)
    }
    
    data_filtered <- data_filtered |>
      mutate(
        City = fct_drop(City),
        Province = fct_drop(Province),
        Pollutant = fct_drop(Pollutant)
      )
    
    data_filtered
  })
  
  # If provinces are selected, update the list of cities
  observeEvent(input$province, ignoreNULL = FALSE, {
    province_cities <- data
    if (length(input$province) > 0) {
      province_cities <-
        province_cities |> filter(Province %in% input$province)
    }
    province_cities <- province_cities |> distinct(City) |> pull()
    
    updateSelectizeInput(session,
                         "city",
                         choices = province_cities,
                         selected = c())
  })
  
  # Radar plot
  output$radarPlot <- renderPlot({
    data_radar <- data_selected() |>
      group_by(Pollutant) |>
      summarise(Value = mean(Value)) |>
      pivot_wider(names_from = "Pollutant", values_from = "Value")
    max <- plyr::round_any(max(data_radar), 10, f = `ceiling`)
    n_col <- ncol(data_radar)
    data_radar <- rbind(rep(max, n_col),
                        rep(0, n_col),
                        data_radar)
    fmsb::radarchart(data_radar, title = "Pollutants")
  })
  
  # Stacked bar chart
  output$stackedBarChart <- renderPlot({
    data_selected() |>
      arrange(Value) |>
      ggplot(aes(x = Date, y = Value, fill = Pollutant)) +
      geom_col() +
      scale_x_date(date_breaks = "years" , date_labels = "%b %y") +
      labs(x = "Date",
           y = "Pollutant level (ppm)",
           title = "Breakdown by pollutants of the monthly average concentration") +
      scale_fill_brewer(palette = "Set2") +
      theme_classic() +
      theme(axis.text.x = element_text(
        angle = 90,
        vjust = 0.5,
        hjust = 1
      ))
  })
  
  # Line plot
  output$linePlot <- renderPlot({
    data_selected() |>
      ggplot(aes(x = Date, y = Value, color = Pollutant)) +
      geom_line() +
      geom_point() +
      scale_x_date(date_breaks = "years" , date_labels = "%b %y") +
      labs(x = "Date",
           y = "Pollutant level (ppm)",
           title = "Monthly pollutant levels") +
      scale_colour_brewer(palette = "Set2") +
      theme_classic() +
      theme(axis.text.x = element_text(
        angle = 90,
        vjust = 0.5,
        hjust = 1
      ))
  })
  
  # Map
  output$map <- renderLeaflet({
    locations <- data_selected() |>
      distinct(Latitude, Longitude, City)
    
    leaflet() |>
      addProviderTiles(providers$CartoDB.Voyager) |>
      addMarkers(data = locations,
                 label = locations |> select(City) |> pull())
  })
}

# Run the application
shinyApp(ui = ui, server = server)
