# ============================================================================
# Urbanization Change Visualization - Freetown
# ============================================================================

# Load required packages
library(sf)
library(ggplot2)
library(dplyr)

# Define file paths
csv_path <- "D:/LoGRI Dropbox/LoGRI Master Folder/2. Projects/2. Country Projects/9. Sierra Leone/13. Output/discovery/Freetown/wards_urbanization_2019_2025.csv"
shp_path <- "D:/LoGRI Dropbox/LoGRI Master Folder/2. Projects/2. Country Projects/9. Sierra Leone/12. Data/2. Build/map_update/Freetown/Western Area Urban Wards.shp"
output_dir <- "D:/LoGRI Dropbox/LoGRI Master Folder/2. Projects/2. Country Projects/9. Sierra Leone/13. Output/discovery"

# Create output directory if it doesn't exist
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load data
urbanization <- read.csv(csv_path)
wards <- st_read(shp_path)

# Convert Ward column to character in both datasets
urbanization <- urbanization %>%
  mutate(Ward = as.character(Ward))

wards <- wards %>%
  mutate(Ward = as.character(Ward))

# Join data to shapefile
wards_data <- wards %>%
  left_join(urbanization, by = "Ward")

# ============================================================================
# 1. Map of building count in 2025
# ============================================================================
p1 <- ggplot(wards_data) +
  geom_sf(aes(fill = buildings_2025), color = "white", size = 0.3) +
  scale_fill_viridis_c(
    name = "Buildings\n2026",
    option = "plasma",
    labels = scales::comma
  ) +
  labs(
    title = "Number of Buildings per Ward (2026)",
    subtitle = "Freetown, Sierra Leone"
  ) +
  coord_sf(xlim = c(st_bbox(wards_data)[1], -13.10),
           ylim = c(st_bbox(wards_data)[2], 8.52)) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

# Save
ggsave(file.path(output_dir, "map_buildings_2026.png"), p1, width = 10, height = 8, dpi = 300)

# ============================================================================
# 2. Map of difference (new buildings 2019-2025)
# ============================================================================
p2 <- ggplot(wards_data) +
  geom_sf(aes(fill = difference), color = "white", size = 0.3) +
  scale_fill_gradient2(
    name = "New\nBuildings",
    low = "#2166ac",
    mid = "#f7f7f7",
    high = "#b2182b",
    midpoint = median(wards_data$difference, na.rm = TRUE),
    labels = scales::comma
  ) +
  labs(
    title = "New Buildings Detected per Ward (2019-2026)",
    subtitle = "Difference between 2026 and 2019"
  ) +
  coord_sf(xlim = c(st_bbox(wards_data)[1], -13.10),
           ylim = c(st_bbox(wards_data)[2], 8.52)) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

# Save
ggsave(file.path(output_dir, "map_difference_2019_2026.png"), p2, width = 10, height = 8, dpi = 300)

# ============================================================================
# 3. Map of growth rate (%)
# ============================================================================
wards_data <- wards_data %>%
  mutate(growth_rate = (difference / buildings_2019) * 100)

p3 <- ggplot(wards_data) +
  geom_sf(aes(fill = growth_rate), color = "white", size = 0.3) +
  scale_fill_viridis_c(
    name = "Growth\n(%)",
    option = "magma",
    labels = function(x) paste0(round(x, 1), "%")
  ) +
  labs(
    title = "Growth Rate per Ward (2019-2026)",
    subtitle = "Percentage increase in number of buildings"
  ) +
  coord_sf(xlim = c(st_bbox(wards_data)[1], -13.10),
           ylim = c(st_bbox(wards_data)[2], 8.52)) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

# Save
ggsave(file.path(output_dir, "map_growth_pct.png"), p3, width = 10, height = 8, dpi = 300)

# ============================================================================
# 4. Bar chart of Wards with most new buildings
# ============================================================================
top_wards <- urbanization %>%
  arrange(desc(difference)) %>%
  head(10)

p4 <- ggplot(top_wards, aes(x = reorder(Ward, difference), y = difference)) +
  geom_col(fill = "#2c7bb6") +
  geom_text(aes(label = scales::comma(difference)), hjust = -0.2, size = 3.5) +
  coord_flip() +
  labs(
    title = "Top 10 Wards - New Buildings (2019-2026)",
    x = "Ward",
    y = "Number of new buildings"
  ) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.major.y = element_blank()
  )

# Save
ggsave(file.path(output_dir, "bars_top10_wards.png"), p4, width = 10, height = 6, dpi = 300)

# ============================================================================
# 5. Summary table
# ============================================================================
summary_stats <- urbanization %>%
  summarise(
    total_buildings_2019 = sum(buildings_2019, na.rm = TRUE),
    total_buildings_2025 = sum(buildings_2025, na.rm = TRUE),
    total_new_buildings = sum(difference, na.rm = TRUE),
    avg_growth_rate = mean(difference / buildings_2019 * 100, na.rm = TRUE),
    num_wards = n()
  )

print("=== SUMMARY STATISTICS ===")
print(summary_stats)

# Save statistics
write.csv(summary_stats, file.path(output_dir, "urbanization_statistics.csv"), row.names = FALSE)

# ============================================================================
# Display maps
# ============================================================================
print(p1)
print(p2)
print(p3)
print(p4)

cat("\n✓ All visualizations have been created and saved!\n")
cat("  - map_buildings_2026.png\n")
cat("  - map_difference_2019_2026.png\n")
cat("  - map_growth_pct.png\n")
cat("  - bars_top10_wards.png\n")
cat("  - urbanization_statistics.csv\n")