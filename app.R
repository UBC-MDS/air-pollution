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

globalVariables(c(NAPS_dataset_path, pollutant.color.palette))

options(shiny.autoreload = TRUE)

pollutants <- c(
  "CO" = "Carbon monoxide",
  "NO" = "Nitrogen oxide",
  "NO2" = "Nitrogen dioxide",
  "NOX" = "Nitrogen oxides",
  "O3" = "Ozone",
  "SO2" = "Sulphur dioxide",
  "PM2.5" = "Particulate matter, max diameter of 2.5μm",
  "PM10" = "Particulate matter, of max diameter of 10μm"
)

pollutant.colors <-
  RColorBrewer::brewer.pal(length(pollutants), pollutant.color.palette)

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
    NAPSID = fct_relevel(as.factor(NAPSID)),
    City = fct_relevel(as.factor(City)),
    Territory = fct_relevel(as.factor(Territory)),
    Pollutant = fct_relevel(as.factor(Pollutant), names(pollutants))
  )

cat("Done\n")

# Define UI for application
ui <- fluidPage(
  # CSS
  includeCSS("styles.css"),
  
  # Incorporate styles generated by color palettes
  tags$head(tags$style(HTML(
    paste(
      '#pollutant .shiny-options-group :nth-child(',
      seq_along(pollutant.colors) ,
      ') label::before { content: "■ "; color: ',
      pollutant.colors,
      '}\n',
      sep = ""
    )
  ))),
  
  # Header
  includeHTML("header.html"),
  
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      dateRangeInput(
        "date",
        "Date:",
        min = min(data$Date),
        max = max(data$Date),
        start = max(min(data$Date), max(data$Date) - years(10) + months(1)),
        end = max(data$Date)
      ),
      selectizeInput(
        "territory",
        "Province/Territory:",
        choices = levels(data$Territory),
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
      selectizeInput(
        "napsid",
        "Monitoring Station ID (NAPSID):",
        choices = levels(data$NAPSID),
        options = list(placeholder = 'All Monitoring Stations'),
        multiple = TRUE
      ),
      checkboxGroupInput(
        "pollutant",
        "Pollutants:",
        choiceNames = paste(names(pollutants), " (", unlist(pollutants), ")", sep = ""),
        choiceValues = names(pollutants),
        selected = c("CO", "NO", "NO2", "O3", "SO2")
      ),
      width = 3
    ),
    
    # Main panel
    mainPanel(tabsetPanel(
      type = "tabs",
      tabPanel(
        "Breakdown of Pollutants",
        fluidRow(column(width = 3, plotOutput("radarPlot")),
                 column(width = 9, plotOutput("stackedBarChart"))),
        fluidRow(column(width = 12, plotOutput("linePlot")))
      ),
      tabPanel("Monitoring Stations",
               fluidRow(column(
                 width = 12, leafletOutput("map", height = 800)
               )),
               fluidRow(
                 p(
                   "Each point is a monitoring station, with the color corresponds to what the pollutants are measured (refer to the panel to the left for the palette)."
                 )
               ))
    ),
    width = 9)
  ),
  
  # Footer
  includeHTML("footer.html"),
  
  title = "Air Pollution Trends across Canada, 2001-2020",
  theme = bslib::bs_theme(version = 5, bootswatch = "lumen")
)

# Define server logic required
server <- function(input, output, session) {
  # Filters the data based on user selections
  data_selected <- reactive({
    data_filtered <- data |>
      filter(between(Date, input$date[1], input$date[2])) |>
      filter(Pollutant %in% input$pollutant)
    
    if (length(input$territory) > 0) {
      data_filtered <- data_filtered |>
        filter(Territory %in% input$territory)
    }
    
    if (length(input$city) > 0) {
      data_filtered <- data_filtered |>
        filter(City %in% input$city)
    }
    
    if (length(input$napsid) > 0) {
      data_filtered <- data_filtered |>
        filter(NAPSID %in% input$napsid)
    }
    
    data_filtered <- data_filtered |>
      mutate(
        City = fct_drop(City),
        Territory = fct_drop(Territory),
        Pollutant = fct_drop(Pollutant)
      )
    
    data_filtered
  })
  
  # If provinces/territories are selected, update the list of cities
  observeEvent(input$territory, ignoreNULL = FALSE, {
    territory_data <- data
    if (length(input$territory) > 0) {
      territory_data <-
        territory_data |> filter(Territory %in% input$territory)
    }
    territory_cities <- territory_data |> distinct(City) |> pull()
    territory_stations <-
      territory_data |> distinct(NAPSID) |> pull()
    
    updateSelectizeInput(session,
                         "city",
                         choices = territory_cities,
                         selected = c())
    updateSelectizeInput(session,
                         "napsid",
                         choices = territory_stations,
                         selected = c())
  })
  
  observeEvent(input$city, ignoreNULL = FALSE, {
    city_data <- data
    if (length(input$city) > 0) {
      city_data <-
        city_data |> filter(City %in% input$city)
    }
    city_stations <- city_data |> distinct(NAPSID) |> pull()
    
    updateSelectizeInput(session,
                         "napsid",
                         choices = city_stations,
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
      scale_x_date(date_breaks = "years" , date_labels = default.date.format) +
      labs(x = "Date",
           y = "Pollutant level (ppm)",
           title = "Breakdown by pollutants of the monthly average concentration") +
      scale_fill_brewer(palette = pollutant.color.palette) +
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
      group_by(Date, Pollutant) |>
      summarize(Value = mean(Value)) |>
      ggplot(aes(x = Date, y = Value, color = Pollutant)) +
      geom_line() +
      geom_point() +
      scale_x_date(date_breaks = "years" , date_labels = default.date.format) +
      labs(x = "Date",
           y = "Pollutant level (ppm)",
           title = "Monthly pollutant levels") +
      scale_colour_brewer(palette = pollutant.color.palette) +
      theme_classic() +
      theme(axis.text.x = element_text(
        angle = 90,
        vjust = 0.5,
        hjust = 1
      ))
  })
  
  # Map
  output$map <- renderLeaflet({
    pollutant.color.factor <-
      colorFactor(pollutant.colors, domain = names(pollutants))
    
    data_selected() |>
      group_by(NAPSID, Pollutant, Latitude, Longitude, City) |>
      summarize(
        Date.Start = format(min(Date), default.date.format),
        Date.End = format(max(Date), default.date.format),
        Value.Min = min(Value),
        Value.Mean = mean(Value),
        Value.Max = max(Value),
        Value.Count = n()
      ) |>
      mutate(
        label = paste(
          "Monitoring Station ID: <strong>",
          NAPSID,
          "</strong><br>",
          "Location: <strong>",
          City,
          "</strong><br>",
          "Pollutant: <strong>",
          Pollutant,
          "</strong>",
          sep = ""
        ) |>
          lapply(htmltools::HTML),
        popup = paste(
          "Monitoring Station ID: <strong>",
          NAPSID,
          "</strong><br>",
          "Location: <strong>",
          City,
          "</strong><br>",
          "Pollutant: <strong>",
          Pollutant,
          "</strong><br><br>",
          "Record Date Range: <strong>",
          Date.Start,
          "</strong> - <strong>",
          Date.End,
          "</strong><br>",
          "Measurement Values: <strong>",
          round(Value.Min, 2),
          "</strong> - <strong>",
          round(Value.Max, 2),
          "</strong> (Mean: <strong>",
          round(Value.Mean, 2),
          "</strong>)",
          sep = ""
        ) |>
          lapply(htmltools::HTML),
      ) |>
      leaflet() |>
      addProviderTiles(providers$CartoDB.Voyager) |>
      addCircleMarkers(
        lng = ~ Longitude,
        lat = ~ Latitude,
        label = ~ label,
        popup = ~ popup,
        color = ~ pollutant.color.factor(Pollutant),
        radius = 4,
        fillOpacity = 0.8,
        stroke = FALSE,
        clusterOptions = markerClusterOptions(
          iconCreateFunction = JS(
            "function (cluster) {
              return new L.DivIcon({
                html: '<div><span>' + cluster.getChildCount() + '</span></div>',
                className: 'marker-cluster marker-cluster-generic',
                iconSize: new L.Point(40, 40)
              });
            }"
          )
        )
      )
  })
}

# Run the application
shinyApp(ui = ui, server = server)
