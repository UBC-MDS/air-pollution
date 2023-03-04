library(shiny)
library(fmsb)
library(plyr)
library(tidyverse)
library(leaflet)

source("config.R")

if (Sys.getenv("PORT") != "") {
  options(shiny.port = as.integer(Sys.getenv("PORT")))
}

globalVariables(c(NAPS_dataset_path))

options(shiny.autoreload=TRUE)

cat("Loading the NAPS dataset. Please wait...")

data <- readr::read_csv(NAPS_dataset_path) |>
  mutate(Territory_Name = case_when(
    Territory == "AB" ~ "Alberta",
    Territory == "BC" ~ "British Columbia",
    Territory == "MB" ~ "Manitoba",
    Territory == "NB" ~ "New Brunswick",
    Territory == "NL" ~ "Newfoundland",
    Territory == "NS" ~ "Nova Scotia" ,
    Territory == "NT" ~ "Northwest Territories",
    Territory == "ON" ~ "Ontario",
    Territory == "PE" ~ "Prince Edward Island",
    Territory == "QC" ~ "Quebec",
    Territory == "SK" ~ "Saskatchewan",
    Territory == "YU" ~ "Yukon",
    TRUE ~ NA
  )) |>
  mutate(City = paste0(City, ", ", Territory),
         Territory = paste0(Territory_Name, " (", Territory, ")")) |>
  mutate(City = fct_relevel(as.factor(City)),
         Territory = fct_relevel(as.factor(Territory)),
         Pollutant = as.factor(Pollutant)) |>
  mutate_if(is.character, utf8::utf8_encode)

cat("Done\n")

# Define UI for application
ui <- fluidPage(

    # Application title
    titlePanel("Air Pollution"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            dateRangeInput("daterange",
                        "Date Range:",
                        min = min(data$Date),
                        max = max(data$Date),
                        start = min(data$Date),
                        end = max(data$Date)),
            selectizeInput("province",
                           "Province/Territory:",
                           choices = levels(data$Territory),
                           options = list(placeholder = 'All Provinces/Territories'),
                           multiple = TRUE
            ),
            selectizeInput("city",
                           "City:",
                           choices = levels(data$City),
                           options = list(placeholder = 'All Cities'),
                           multiple = TRUE
            ),
            checkboxGroupInput("pollutant",
                               "Pollutants:",
                               choices = levels(data$Pollutant),
                               selected = levels(data$Pollutant)
            )
        ),
        mainPanel(
          tabsetPanel(type = "tabs",
                      tabPanel("Breakdown of Pollutants",
                               fluidRow(
                                 column(width=5, plotOutput("radarPlot")),
                                 column(width=7, plotOutput("stackedBarChart"))
                               )
                      ),
                      tabPanel("Map", leafletOutput("map"))
        ))
    ),
    HTML("<h5><b>Definitions</b></h5>
         <ul>
          <li>CO: Carbon monoxide</li>
          <li>NO: Nitrogen oxide</li>
          <li>NO2: Nitrogen dioxide</li>
          <li>NOX: Nitrogen oxides </li>
          <li>O3: Ozone</li>
          <li>PM10: Particulate matter less than or equal to 2.5 micrometres</li>
          <li>PM2.5: particulate matter less than or equal to 10 micrometres</li>
          <li>SO2: Sulphur dioxide</li>
         </ul>"
    ),
    hr(),
    HTML("<p><b>Authors:</b> Elena Ganacheva, Ritisha Sharma, Ranjit Sundaramurthi, Kelvin Wong</p> 
        <p><b>Attribution:</b> <a href = https://www.canada.ca/en/environment-climate-change/services/air-pollution/monitoring-networks-data/national-air-pollution-program.html>The National Air Pollution Surveillance (NAPS) data</a> is published by the Government of Canada, 
         under the terms of the Open Government License - Canada.</p>")
)

# Define server logic required
server <- function(input, output, session) {
  
    #Filters the data based on user selections
    data_selected <- reactive({
      data_filtered <- data |>
        filter(between(Date, input$daterange[1], input$daterange[2])) |>
        filter(Pollutant %in% input$pollutant)

      if (length(input$province) > 0) {
        data_filtered <- data_filtered |>
          filter(Territory %in% input$province)
      }

      if (length(input$city) > 0) {
        data_filtered <- data_filtered |>
          filter(City %in% input$city)
      }

      data_filtered
    })
    
    # If provinces are selected, update the list of cities
    observeEvent(input$province, ignoreNULL = FALSE, {
      if (length(input$province) > 0) {
        province_cities <- data |> filter(Territory %in% input$province) |> distinct(City) |> pull()
      } else {
        province_cities <- data |> distinct(City) |> pull()
      }

      updateSelectizeInput(session, "city",
                           choices = province_cities,
                           selected = c())
    })
    
    #Produces a radar plot
    output$radarPlot <- renderPlot({
      data_radar <- data_selected() |> 
        dplyr::group_by(Pollutant) |> 
        dplyr::summarise(Value = mean(Value)) |>
        tidyr::pivot_wider(names_from = "Pollutant", values_from = "Value")
      max <- plyr::round_any(max(data_radar), 10, f=`ceiling`)
      n_col <- ncol(data_radar)
      data_radar <- rbind(rep(max,n_col), rep(0,n_col), data_radar)
      
      fmsb::radarchart(data_radar)
    })
    
    # Stacked bar chart
    output$stackedBarChart <- renderPlot({
      bar_df <- data_selected()
      
      bar_df$year_month <- format(as.Date(bar_df$Date), "%y-%m")

      bar_df <- bar_df |>
        dplyr::group_by(year_month, Pollutant) |>
        dplyr::summarise(avg_val = mean(Value)) |>
        arrange(avg_val)
      
      pollutant_order <- c("CO", "SO2", "NO", "NO2", "PM2.5", "NOX", "PM10", "O3")
      bar_df$Pollutant <- factor(bar_df$Pollutant, 
                                 levels = pollutant_order)
        
      ggplot(bar_df, aes(x = year_month, y = avg_val, fill = Pollutant)) +
        geom_col() +
        labs(x = "Year-Month",
             y = "Monthly average concentration (ppm)",
             title = "Breakdown by pollutants of the monthly average concentration") +
        scale_fill_brewer(palette = "Set2", labels = pollutant_order) +
        theme_classic()
    })

    # Map
    output$map <- renderLeaflet({
      locations <- data_selected() |>
        distinct(Latitude, Longitude, City)

      leaflet() |>
        addProviderTiles(providers$CartoDB.Voyager,
                         options = providerTileOptions(noWrap = TRUE)) |>
        addMarkers(data = locations,
                   label = locations |> select(City) |> pull())
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
