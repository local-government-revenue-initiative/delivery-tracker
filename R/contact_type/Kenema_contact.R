# ==============================================================================
# Project: LoGRI Sierra Leone - Contact Type Analysis
# Purpose: Visualize distribution of contact types in Kenema
# Author: [Your Name]
# Date: 2024-12-04
# ==============================================================================

# Load required packages
library(tidyverse)
library(scales)
library(here)

# Set working directory and paths
input_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/data/1_Raw/contact_type/Kenema"
output_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/output/contact_type/Kenema"

# Create output directory if it doesn't exist
if (!dir.exists(output_path)) {
  dir.create(output_path, recursive = TRUE)
}

# ==============================================================================
# 1. LOAD DATA
# ==============================================================================

# Read CSV file
contacts <- read.csv(
  file.path(input_path, "list_of_contacts_KCC_KENEMA.csv"),
  stringsAsFactors = FALSE
)

# Quick data check
glimpse(contacts)

# ==============================================================================
# 2. DATA PREPARATION
# ==============================================================================

# Calculate frequencies and percentages
contact_summary <- contacts %>%
  count(contact_type) %>%
  mutate(
    percentage = n / sum(n) * 100,
    label = paste0(n, "\n(", round(percentage, 1), "%)")
  )

print(contact_summary)

# ==============================================================================
# 3. VISUALIZATION 1: BAR CHART (SIMPLE & ELEGANT)
# ==============================================================================

plot1 <- ggplot(contact_summary, aes(x = contact_type, y = n, fill = contact_type)) +
  geom_col(width = 0.7, alpha = 0.9) +
  geom_text(aes(label = label), 
            vjust = -0.5, 
            size = 4.5,
            fontface = "bold") +
  scale_fill_manual(values = c("Owner" = "#2C3E50", "Tenant" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Distribution of Contact Types",
    subtitle = "Kenema City Council - Property Contacts",
    x = NULL,
    y = "Number of Contacts",
    caption = "Source: LoGRI Sierra Leone | KCC Property Tax Database"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0),
    plot.subtitle = element_text(size = 12, color = "grey40", hjust = 0),
    plot.caption = element_text(size = 9, color = "grey50"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text = element_text(size = 12, face = "bold"),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save plot
ggsave(
  filename = file.path(output_path, "contact_type_barchart.png"),
  plot = plot1,
  width = 10,
  height = 7,
  dpi = 300,
  bg = "white"
)

# ==============================================================================
# 4. VISUALIZATION 2: PIE CHART (ALTERNATIVE)
# ==============================================================================

plot2 <- ggplot(contact_summary, aes(x = "", y = n, fill = contact_type)) +
  geom_col(width = 1, color = "white", size = 2) +
  coord_polar(theta = "y") +
  geom_text(aes(label = label),
            position = position_stack(vjust = 0.5),
            size = 5,
            fontface = "bold",
            color = "white") +
  scale_fill_manual(values = c("Owner" = "#2C3E50", "Tenant" = "#E74C3C")) +
  labs(
    title = "Contact Type Distribution",
    subtitle = "Kenema City Council",
    caption = "Source: LoGRI Sierra Leone",
    fill = "Contact Type"
  ) +
  theme_void(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0.5),
    plot.subtitle = element_text(size = 12, color = "grey40", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "grey50"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 12),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save plot
ggsave(
  filename = file.path(output_path, "contact_type_piechart.png"),
  plot = plot2,
  width = 8,
  height = 8,
  dpi = 300,
  bg = "white"
)

# ==============================================================================
# 5. VISUALIZATION 3: HORIZONTAL BAR (FOR REPORTS)
# ==============================================================================

plot3 <- ggplot(contact_summary, aes(x = reorder(contact_type, n), y = n, fill = contact_type)) +
  geom_col(alpha = 0.9) +
  geom_text(aes(label = paste0(n, " (", round(percentage, 1), "%)")), 
            hjust = -0.1, 
            size = 5,
            fontface = "bold") +
  scale_fill_manual(values = c("Owner" = "#2C3E50", "Tenant" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  coord_flip() +
  labs(
    title = "Contact Type Distribution - Kenema",
    x = NULL,
    y = "Number of Contacts",
    caption = "Source: LoGRI Sierra Leone"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.caption = element_text(size = 9, color = "grey50"),
    legend.position = "none",
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text = element_text(size = 12, face = "bold"),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save plot
ggsave(
  filename = file.path(output_path, "contact_type_horizontal.png"),
  plot = plot3,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

# ==============================================================================
# 6. EXPORT SUMMARY TABLE
# ==============================================================================

# Export summary statistics as CSV
write.csv(
  contact_summary,
  file.path(output_path, "contact_type_summary.csv"),
  row.names = FALSE
)

# ==============================================================================
# 7. PRINT SUMMARY
# ==============================================================================

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Total contacts:", nrow(contacts), "\n")
cat("\nDistribution:\n")
print(contact_summary)
cat("\nOutputs saved to:", output_path, "\n")
cat("  - contact_type_barchart.png\n")
cat("  - contact_type_piechart.png\n")
cat("  - contact_type_horizontal.png\n")
cat("  - contact_type_summary.csv\n")



# ==============================================================================
# Project: LoGRI Sierra Leone - Contact Type Analysis
# Purpose: Visualize distribution of contact types in Freetown
# Author: [Your Name]
# Date: 2024-12-04
# ==============================================================================

# Load required packages
library(tidyverse)
library(scales)

# Set working directory and paths
input_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/data/1_Raw/contact_type/Freetown"
output_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/output/contact_type/Freetown"

# Create output directory if it doesn't exist
if (!dir.exists(output_path)) {
  dir.create(output_path, recursive = TRUE)
}

# ==============================================================================
# 1. LOAD DATA
# ==============================================================================

# Read CSV file
contacts <- read.csv(
  file.path(input_path, "list_of_contacts_FCC_FREETOWN.csv"),
  stringsAsFactors = FALSE
)

# Quick data check
glimpse(contacts)

# ==============================================================================
# 2. DATA PREPARATION
# ==============================================================================

# Calculate frequencies and percentages
contact_summary <- contacts %>%
  count(contact_type) %>%
  mutate(
    percentage = n / sum(n) * 100,
    label = paste0(n, "\n(", round(percentage, 1), "%)")
  )

print(contact_summary)

# ==============================================================================
# 3. VISUALIZATION: BAR CHART (SIMPLE & ELEGANT)
# ==============================================================================

plot1 <- ggplot(contact_summary, aes(x = contact_type, y = n, fill = contact_type)) +
  geom_col(width = 0.7, alpha = 0.9) +
  geom_text(aes(label = label), 
            vjust = -0.5, 
            size = 4.5,
            fontface = "bold") +
  scale_fill_manual(values = c("Owner" = "#2C3E50", "Tenant" = "#E74C3C")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Distribution of Contact Types",
    subtitle = "Freetown City Council - Property Contacts",
    x = NULL,
    y = "Number of Contacts",
    caption = "Source: LoGRI Sierra Leone | FCC Property Tax Database"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0),
    plot.subtitle = element_text(size = 12, color = "grey40", hjust = 0),
    plot.caption = element_text(size = 9, color = "grey50"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text = element_text(size = 12, face = "bold"),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save plot
ggsave(
  filename = file.path(output_path, "contact_type_barchart.png"),
  plot = plot1,
  width = 10,
  height = 7,
  dpi = 300,
  bg = "white"
)

# ==============================================================================
# 4. EXPORT SUMMARY TABLE
# ==============================================================================

# Export summary statistics as CSV
write.csv(
  contact_summary,
  file.path(output_path, "contact_type_summary.csv"),
  row.names = FALSE
)

# ==============================================================================
# 5. PRINT SUMMARY
# ==============================================================================

cat("\n=== ANALYSIS COMPLETE - FREETOWN ===\n")
cat("Total contacts:", nrow(contacts), "\n")
cat("\nDistribution:\n")
print(contact_summary)
cat("\nOutputs saved to:", output_path, "\n")
cat("  - contact_type_barchart.png\n")
cat("  - contact_type_summary.csv\n")


# Read Kenema data
kenema_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/data/1_Raw/contact_type/Kenema"
kenema <- read.csv(
  file.path(kenema_path, "list_of_contacts_KCC_KENEMA.csv"),
  stringsAsFactors = FALSE
)

# Count unique properties
kenema_unique_properties <- n_distinct(kenema$property)
kenema_total_contacts <- nrow(kenema)

# ==============================================================================
# FREETOWN - Unique Properties
# ==============================================================================

# Read Freetown data
freetown_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/data/1_Raw/contact_type/Freetown"
freetown <- read.csv(
  file.path(freetown_path, "list_of_contacts_FCC_FREETOWN.csv"),
  stringsAsFactors = FALSE
)

# Count unique properties
freetown_unique_properties <- n_distinct(freetown$property)
freetown_total_contacts <- nrow(freetown)
