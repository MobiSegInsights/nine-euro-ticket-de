# Understanding the impact of the 9-Euro Ticket Scheme in Germany on mobility, activity, and segregation
A perspective of big mobile phone geolocation data, part of the [parent project](https://github.com/MobiSegInsights).

The German government launched an innovative pilot project in the summer of 2022, offering a ‘9-Euro Ticket’ for unlimited monthly travel on trains and buses in June, July, and August. 
This initiative was designed to boost the use of public transportation and evaluate its effects on traffic patterns and commuting habits. 
Traditionally, studies on such changes have depended on travel survey data.
This research adopts a novel approach by analyzing extensive anonymized mobile geolocation data from the phones of German adults, spanning 15 months across May to September for the years 2019, 2022, and 2023. 
This study aims to investigate the adult population's mobility and activity trends and their resulted socio-spatial segregation patterns.
Through this study, we aim to gain a deeper understanding of the shifts in societal movement triggered by the ‘9-Euro Ticket’ initiative while also accounting for the increase in travel following the easing of COVID-19 restrictions.

## Data
Large-scale geolocation data gathered from multiple sources presents a unique chance to gain insights into human movement patterns and the physical layout of spaces.
Mobile application geolocation data, an economical option for collecting anonymized data on population movement, records the GPS coordinates and timestamps of smartphone users engaging with apps that have location tracking enabled. 
These data provide detailed spatial and temporal geolocations across a wide demographic, all while maintaining user privacy by omitting personal details.

An existing dataset of anonymised MAD for Germany is available, covering 15 months in 2019, 2022, and 2023. 
Due to privacy concerns, the raw data cannot be shared. 
However, we will make available aggregated outcomes of mobility, activity, and social segregation changes. 
These results will be provided with detailed spatial and temporal precision for public access.

## Scripts
The repo contains the scripts (`src/`), libraries (`lib/`) for conducting the data processing, analysis, and visualisation.
The original input data are stored under `dbs/` locally and intermediate results are stored in a local database.
Only results directly used for visualisation and upcoming article writing are stored under `results/`.
The produced figures are stored under `figures/`.