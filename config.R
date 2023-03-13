# NAPS dataset path
# By default, it uses the monthly data build from 2001-2020, hosted on GitHub.
# Change it here to point to a local data path, or data covering other time
# frame instead.
NAPS_dataset_path <-
    'https://github.com/netsgnut/canada-naps-data/releases/download/build-latest/CA_NAPS_Monthly_2001-2020.csv'

# Color palette set
# This is passed to the RColorBrewer
pollutant.color.palette <- 'Set2'

# Default date format
# Refer to R documentation for more
default.date.format <- "%b %Y"
