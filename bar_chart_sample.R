library(lubridate)
library(dplyr)
library(ggplot2)

air_df <- read.csv("data/CA_NAPS_Daily_2020.csv")
data <- readr::read_csv("data/CA_NAPS_Daily_2020.csv")


date <- lubridate::ymd(air_df$Date)
air_df$year <- year(date)
air_df$year <- as.factor(air_df$year)
air_df$Pollutant <- as.factor(air_df$Pollutant)

bar_df <- air_df |>
  dplyr::group_by(year, Pollutant) |>
  dplyr::summarise(avg_val = mean(Value)) |>
  arrange(avg_val) # |>
  # filter(year >= input$year_range[1] & year <= input$year_range[2])

pollutant_order <- c("CO", "SO2", "NO", "NO2", "PM2.5", "NOX", "PM10", "O3")
bar_df$Pollutant <- factor(bar_df$Pollutant, 
                           levels = pollutant_order)

ggplot(bar_df, aes(x = year, y = avg_val, fill = Pollutant)) +
  geom_col() +
  labs(x = "Year",
       y = "Average concentration (ppm)",
       title = "Breakdown of the average concentration of pollution \nby pollutant over given years") +
  scale_fill_brewer(palette = "Spectral", labels = pollutant_order) +
  theme_classic()
