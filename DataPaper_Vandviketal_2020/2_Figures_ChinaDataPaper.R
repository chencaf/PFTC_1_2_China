#### China Data paper

##load packages
library("tidyverse")
library("vegan")
library("ggvegan")
library("cowplot")
#library("gridExtra")
library("lubridate")
library("patchwork")

theme_set(theme_bw())

source("community/start_here.R")


## ----DiversityPlot
# Richness, evenness etc.
#turf environment
turf_env <- tbl(con, "turfEnvironment") %>% collect()


## functional groups
fun_gp <- tbl(con, "taxon") %>% 
  select(species, functionalGroup) %>% 
  collect()

elev <- tibble(destSiteID = c("H", "A", "M", "L"),
               Elevation = c(4130, 3850, 3500, 3000))

## Calculate responses
responses <- cover_thin %>% 
  left_join(fun_gp, by = "species") %>% 
  left_join(turf_env, by = c("turfID", "year")) %>% 
  left_join(elev, by = "destSiteID") %>% 
  group_by(turfID, originBlockID, TTtreat, originSiteID, year, Elevation) %>%  
  summarise(Richness = n(), 
            diversity = diversity(cover), 
            N1 = exp(diversity),
            Evenness = diversity/log(Richness),
            SumofCover = sum(cover),
            ProportionGraminoid = sum(cover[functionalGroup %in% c("gramineae", "sedge")])/SumofCover,
            total_vascular = first(totalVascular),
            vegetationHeight = mean(vegetationHeight)
  )

# Gradient
ResponsesGradient <- responses %>% 
  filter(TTtreat %in% c("local", "control"), year == 2016) %>% 
  select(-N1, -diversity, -total_vascular, -vegetationHeight) %>% 
  gather(key = Index, value = Value, -turfID, -originBlockID, -TTtreat, -originSiteID,  -year, -Elevation) %>% 
  mutate(Index = factor(Index, levels = c("Richness", "Evenness", "SumofCover", "ProportionGraminoid")))

MeanGradResponse <- ResponsesGradient %>% 
  group_by(Index, Elevation, TTtreat) %>% 
  summarise(Ave_value = mean(Value)) %>% 
  ungroup() %>% 
  filter(!is.na(Ave_value))

GradientPlot <- ResponsesGradient %>% 
  ggplot(aes(x = Elevation, y = Value, colour = originSiteID, shape = TTtreat)) +
  geom_jitter(height = 0, width = 0.1, size = 1.8) +
  geom_line(data = MeanGradResponse, aes(x = Elevation, y = Ave_value), colour = "grey", linetype = "dashed", size = 0.8) +
  scale_color_brewer(palette = "RdBu", direction = -1) +
  scale_shape_manual(values = c(1, 16)) +
  scale_x_continuous(breaks = c(3000, 3200, 3400, 3600, 3800, 4000, 4200)) +
  labs(x = "Elevation m a.s.l.", y = "Average value", shape = "Treatment", colour = "Site") +
  facet_wrap( ~ Index, scale = "free", ncol = 1) +
  theme(legend.position = "none")


# Experiments
responsesExp <- responses %>% 
  filter(year == 2016) %>% 
  ungroup() %>% 
  mutate(contrast = plyr::mapvalues(TTtreat, c("control", "local", "warm1", "cool1", "warm3", "cool3", "OTC"), c(0, 0, -1, 1, -3, 3, -1)),
         contrast = as.numeric(as.character(contrast))) %>% 
  select(-N1, -total_vascular, -diversity, -vegetationHeight) %>% 
  gather(key = Index, value = Value, Richness, Evenness, SumofCover, ProportionGraminoid)

otc <- responsesExp %>% 
  filter(TTtreat %in% c("control", "OTC")) %>% 
  mutate (experiment = "OTC")

extremeTransplant <- responsesExp %>% 
  filter(TTtreat %in% c("control", "warm3", "cool3")) %>% 
  mutate (experiment = "Extreme transplant")

transplant <- responsesExp %>% 
  filter(TTtreat %in% c("control", "warm1", "cool1")) %>% 
  mutate (experiment = "Transplant")

mean_responses <- otc %>% 
  bind_rows(transplant, extremeTransplant) %>% 
  group_by(TTtreat, originSiteID, contrast, experiment, Index) %>% 
  summarise(Ave_value = mean(Value)) %>% 
  mutate(Index = factor(Index, levels = c("Richness", "Evenness", "SumofCover", "ProportionGraminoid")))


# treatments
ContrastPlot <- responses %>% 
  filter(year == 2016) %>% 
  select(-N1, -total_vascular, -diversity, -vegetationHeight) %>% 
  gather(key = Index, value = Value, Richness, Evenness, SumofCover, ProportionGraminoid) %>% 
  mutate(Index = factor(Index, levels = c("Richness", "Evenness", "SumofCover", "ProportionGraminoid"))) %>% 
  mutate(contrast = plyr::mapvalues(TTtreat, c("control", "local", "warm1", "cool1", "warm3", "cool3", "OTC"), c(0, 0, -1, 1, -3, 3, -1)),
         contrast = as.numeric(as.character(contrast))) %>% 
  ggplot(aes(x = contrast, y = Value, colour = originSiteID, shape = TTtreat)) +
  geom_jitter(height = 0, width = 0.1, size = 1.8) +
  geom_line(data = mean_responses, aes(y = Ave_value, x = contrast, colour = originSiteID, linetype = experiment), inherit.aes = FALSE, size = 0.8) +
  scale_color_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  scale_linetype_manual(values = c("dashed", "solid", "dotted")) +
  scale_shape_manual(values = c(1, 16, 15, 17, 18, 6, 7), labels=c("Control", "Local transplant", "Warming", "Cooling", "Extreme warming", "Extreme cooling", "OTC")) +
  labs(x = "Contrast levels", y = "", colour = "Site", linetype = "Experiment", shape = "Treatment") +
  scale_x_continuous(breaks = c(-3, 0, 3), labels = c("warmer", "control", "cooler")) +
  facet_wrap(~ Index, scales = "free", ncol = 1)
#+ theme(axis.text.x = element_text(values = c("cooler", "control", "warmer")))


plot_grid(GradientPlot, ContrastPlot, ncol = 2, rel_widths = c(1.3, 2))
#Diversity <- plot_grid(GradientPlot, ContrastPlot, ncol = 2, rel_widths = c(1.3, 2))
#ggsave(Diversity, filename = "Diversity.pdf", height = 10, width = 10, dpi = 300)


## ----TraitDistribution
# Trait distributions
traitsLeaf <- read_csv(file = "traits/data_cleaned/PFTC1.2_China_2015_2016_LeafTraits.csv", col_names = TRUE)
traitsChem <- read_csv(file = "traits/data_cleaned/PFTC1.2_China_2015_2016_ChemicalTraits.csv", col_names = TRUE)

traitsWideL <- traitsLeaf %>% 
  mutate(Wet_Mass_g.log = log(Wet_Mass_g),
         Dry_Mass_g.log = log(Dry_Mass_g),
         Leaf_Thickness_Ave_mm.log = log(Leaf_Thickness_Ave_mm),
         Leaf_Area_cm2.log = log(Leaf_Area_cm2)) %>% 
  mutate(Site = factor(Site, levels = c("H", "A", "M", "L"))) 


traitsLongL <- traitsWideL %>% 
  select(Date, Elevation, Site, Taxon, Individual_number, Leaf_number, Wet_Mass_g.log, Dry_Mass_g.log, Leaf_Thickness_Ave_mm.log, Leaf_Area_cm2.log, SLA_cm2_g, LDMC) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Taxon, -Individual_number, -Leaf_number) %>% 
  filter(!is.na(Value))


traitsLongC <- traitsChem %>% 
  select(Date, Elevation, Site, Taxon, P_percent, C_percent, N_percent, CN_ratio, dN15_permil, dC13_permil) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Taxon)

traitsLong <- traitsLongL %>% bind_rows(traitsLongC)

controlTraitDist <- traitsLong %>% 
  filter(!is.na(Value)) %>% 
  mutate(Traits = factor(Traits, levels = c("Wet_Mass_g.log", "Dry_Mass_g.log", "Leaf_Thickness_Ave_mm.log", "Leaf_Area_cm2.log", "SLA_cm2_g", "LDMC", "P_percent", "C_percent", "N_percent", "CN_ratio", "dN15_permil", "dC13_permil"))) %>% 
  ggplot(aes(x = Value, fill = Site)) +
  geom_density(alpha = 0.5) +
  scale_fill_brewer(palette = "RdBu", direction = -1, labels=c("High alpine", "Alpine", "Middle", "Lowland")) +
  labs(x = "Mean trait value", y = "Density") +
  facet_wrap( ~ Traits, scales = "free") +
  theme(legend.position="top")
controlTraitDist
#ggsave(controlTraitDist, filename = "controlTraitDist.pdf", height = 13, width = 13, dpi = 300)

## ----Stuff
traitsLong %>% 
  filter(!is.na(Value)) %>% 
  group_by(Traits) %>% 
  summarise(min = min(Value, na.rm = TRUE), max = max(Value, na.rm = TRUE))

traitsLeaf %>% 
  group_by() %>% 
  summarise(min(Leaf_Thickness_Ave_mm, na.rm = TRUE), max(Leaf_Thickness_Ave_mm, na.rm = TRUE))


## ----OtherStuff
# How many leaves
traitsLeaf %>% 
  mutate(Wet_Mass_g.log = log(Wet_Mass_g),
         Dry_Mass_g.log = log(Dry_Mass_g),
         Leaf_Thickness_Ave_mm.log = log(Leaf_Thickness_Ave_mm),
         Leaf_Area_cm2.log = log(Leaf_Area_cm2)) %>% 
  select(Date, Elevation, Site, Treatment, Taxon, Individual_number, Leaf_number, Wet_Mass_g.log, Dry_Mass_g.log, Leaf_Thickness_Ave_mm.log, Leaf_Area_cm2.log, SLA_cm2_g, LDMC) %>% 
  gather(key = Traits, value = Value, -Date, -Elevation, -Site, -Treatment, -Taxon, -Individual_number, -Leaf_number) %>% 
  filter(!is.na(Value)) %>% 
  #group_by(Treatment) %>% 
  summarise(n())
# Total: 33'314
 
traitsLeaf %>% 
  filter(Treatment != "LOCAL") %>% 
  group_by(Taxon) %>% 
  summarise(n())


traitsChem %>% 
  select(Elevation, Site,  Treatment, Taxon, StoichLabel, P_percent, C_percent, N_percent, CN_ratio, dN15_percent, dC13_percent) %>% 
  gather(key = Trait, value = Value, C_percent, N_percent, CN_ratio, dN15_percent, dC13_percent, P_percent) %>% 
  filter(!is.na(Value)) %>% 
  group_by(Treatment) %>% 
  summarise(n())
# Total obs: 3429

# Nr leaves: 6671
# Nr trait observations: 33314 + 3429 = 36743

traitsChem %>% 
  group_by(Treatment) %>% 
  summarise(n())
# Total leaves: 576, gradient: 265, experiment: 311

traitsLeaf %>% distinct(Taxon)
# Taxon: 193

## ----Climate figure
# Climate figure
# Read in Air data
airtemp <- read_csv(file = "climate/data_cleaned/China_2013_2016_AirTemp.csv", col_names = TRUE)

AirTempPlot <- airtemp %>% 
  mutate(site = plyr::mapvalues(site, c("H", "A", "M", "L"), c("High alpine", "Alpine", "Middle", "Lowland"))) %>% 
  mutate(site = factor(site, levels = c("High alpine", "Alpine", "Middle", "Lowland"))) %>% 
  ggplot(aes(x = dateTime, y = Tair, colour = site)) +
  geom_line() +
  scale_color_brewer(palette = "RdBu", direction = -1, name = "Site") +
  labs(x = "", y = "Mean air temperature °C") +
  facet_wrap(~ site) +
  theme(legend.position="top")


# iButton
monthlyiButton <- read_csv(file = "climate/data_cleaned/China_2019_Monthly_TemperatureiButton.csv", col_names = TRUE)

iButtonPlot <- monthlyiButton %>% 
  filter(depth == "air") %>% 
  mutate(site = plyr::mapvalues(site, c("H", "A", "M", "L"), c("High alpine", "Alpine", "Middle", "Lowland"))) %>% 
  mutate(site = factor(site, levels = c("High alpine", "Alpine", "Middle", "Lowland"))) %>% 
  ggplot(aes(x = site, y = Tmean, fill = treatment)) +
  geom_boxplot() +
  scale_fill_manual(name = "Treatment", values = c("grey", "purple"), labels=c("Control", "OTC")) +
  labs(x = "", y = "Mean summer temperature °C") +
  theme(legend.position="top")


# Read in Tomst data
temp <- read_csv(file = "climate/data_cleaned/China_2019_Climate_TomstLogger.csv")


TomstOTC <- temp %>%
  group_by(YearMonth, Variable, Treatment) %>%
  summarise(MeanTemperature = mean(Temperature), SETemperature = sd(Temperature)/sqrt(n())) %>%
  ungroup() %>% 
  mutate(Variable = str_remove(Variable, "Temperature")) %>% 
  ggplot(aes(x = YearMonth, y = MeanTemperature, ymin = MeanTemperature - SETemperature, ymax = MeanTemperature + SETemperature, colour = Treatment)) +
  scale_colour_manual(name = "Treatment", values = c("grey", "purple"), labels=c("Control", "OTC")) +
  geom_point() +
  geom_line() +
  geom_errorbar(width = 0.1) +
  scale_x_date(date_labels = "%b", breaks = ymd(c("2019-09-15", "2019-10-15", "2019-11-15"))) +
  labs(x = "", y = "Mean temperautre in °C") +
  facet_wrap(~ Variable) +
  theme(legend.position="top")
  


ClimatePlot <- AirTempPlot / (iButtonPlot + TomstOTC) + plot_annotation(tag_levels = "a")
ClimatePlot
#ggsave(ClimatePlot, filename = "ClimatePlot.pdf", height = 10, width = 10, dpi = 300)






## ----SpList
### SPECIES TABLE
biomass <- read_csv(file = "biomass/China_2016_Biomass_cleaned.csv")
traitsLeaf <- read_csv(file = "traits/data_cleaned/PFTC1.2_China_2015_2016_LeafTraits.csv")


spList <- cover_thin %>% distinct(speciesName) %>%   
  mutate(Dataset = "community") %>% 
  rbind(biomass %>% select(speciesName) %>% 
          distinct() %>% 
          mutate(Dataset = "biomass")) %>% 
  rbind(traitsLeaf %>% select(Taxon) %>% 
          rename("speciesName" = "Taxon") %>% 
          distinct() %>% 
          mutate(Dataset = "trait")) %>% 
  mutate(Presence = "x") %>% 
  pivot_wider(names_from = Dataset, values_from = Presence) %>% 
  arrange(speciesName) %>% 
  filter(!grepl("*Unkown|*mixed forb species|spp$|spp.$|sp$|sp1$|sp2$|sp4$", speciesName))
spList
#writexl::write_xlsx(spList, path = "China_FullSpeciesList.xlsx")

taxa %>% select(speciesName) %>%  
  mutate(Dataset = "community") %>% 
  rbind(biomass %>% select(speciesName) %>% 
          distinct() %>% 
          mutate(Dataset = "biomass")) %>% 
  rbind(traitsLeaf %>% select(Taxon) %>% 
          rename("speciesName" = "Taxon") %>% 
          distinct() %>% 
          mutate(Dataset = "trait")) %>% 
  mutate(Presence = "x") %>% 
  pivot_wider(names_from = Dataset, values_from = Presence) %>% 
  arrange(speciesName) %>% 
  filter(grepl("*Unkown|*mixed forb species|spp$|spp.$|sp$|sp1$|sp2$|sp4$", speciesName)) %>% 
  gather(key = dataset, value = present, -speciesName) %>% 
  filter(present == "x") %>% 
  group_by(dataset) %>% 
  count()


airtemp <- read_csv(file = "climate/data_cleaned/China_2013_2016_AirTemp.csv", col_names = TRUE)

# GDD
airtemp %>% 
  mutate(year = year(dateTime),
         month = month(dateTime),
         day = day(dateTime)) %>% 
  filter(year %in% c(2013)) %>% 
  group_by(site, year, month, day) %>% 
  summarise(mean = mean(Tair)) %>% 
  filter(mean >= 5) %>%
  group_by(year, site) %>% 
  summarise(n = n())

# Freezing days
airtemp %>% 
  mutate(year = year(dateTime),
         month = month(dateTime),
         day = day(dateTime)) %>% 
  filter(year %in% c(2013)) %>% 
  group_by(site, year, month, day) %>% 
  summarise(mean = mean(Tair)) %>% 
  filter(mean < 0) %>%
  group_by(year, site) %>% 
  summarise(n = n())


# Table 4
tbl(con, "turfEnvironment") %>%
  collect() %>% 
  pivot_longer(cols = c(moss:litterThickness), names_to = "group", values_to = "value") %>% 
  group_by(group) %>% 
  summarise(min = min(value, na.rm = TRUE), max = max(value, na.rm = TRUE)) %>% 
  print(n = Inf)


tbl(con, "turfEnvironment") %>%
  collect() %>% 
  pivot_longer(cols = c(moss:litterThickness), names_to = "group", values_to = "value") %>% 
  ggplot(aes(x = factor(year), y = value)) +
  geom_boxplot() +
  facet_wrap(~ group, scales = "free")
