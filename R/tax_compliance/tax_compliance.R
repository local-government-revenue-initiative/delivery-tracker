# ==============================================================================
# VISUALISATION: Payment Compliance Status - Makeni
# ==============================================================================

# ------------------------------------------------------------------------------
# Load required packages
# ------------------------------------------------------------------------------
library(haven)        # Read Stata files
library(tidyverse)    # Data manipulation and ggplot2
library(scales)       # Format percentages

# ------------------------------------------------------------------------------
# Set paths
# ------------------------------------------------------------------------------
input_path <- "D:/Dropbox/LoGRI/Sierra_Leone/data/3_Final/tax_compliance/Makeni"
output_path <- "D:/Dropbox/LoGRI/Sierra_Leone/output/tax_compliance/Makeni"

# Load data
data <- read_dta(file.path(input_path, "makeni_compliance_analysis.dta"))

# ------------------------------------------------------------------------------
# Prepare data for visualization
# ------------------------------------------------------------------------------
status_summary <- data %>%
  count(status) %>%
  mutate(
    percentage = n / sum(n) * 100,
    status_label = factor(status,
                          levels = c(0, 1, 2),
                          labels = c("Remains in default",
                                     "Paid before enforcement",
                                     "Paid after enforcement")),
    # Color palette: red for default, yellow for before, green for after
    fill_color = case_when(
      status == 0 ~ "#E74C3C",  # Red
      status == 1 ~ "#F39C12",  # Orange
      status == 2 ~ "#27AE60"   # Green
    )
  )

# ------------------------------------------------------------------------------
# Prepare breakdown by delivery_type and bank for status == 2
# ------------------------------------------------------------------------------
status2_delivery <- data %>%
  filter(status == 2) %>%
  count(delivery_type) %>%
  mutate(
    percentage = n / sum(n) * 100,
    category = "By Delivery Type"
  ) %>%
  rename(group = delivery_type)

status2_bank <- data %>%
  filter(status == 2) %>%
  count(bank) %>%
  mutate(
    percentage = n / sum(n) * 100,
    category = "By Bank"
  ) %>%
  rename(group = bank)

status2_breakdown <- bind_rows(status2_delivery, status2_bank) %>%
  mutate(group = as.character(group))

# ------------------------------------------------------------------------------
# Create beautiful bar chart
# ------------------------------------------------------------------------------
p1 <- ggplot(status_summary, aes(x = reorder(status_label, -n), y = n, fill = fill_color)) +
  geom_bar(stat = "identity", width = 0.7) +
  geom_text(aes(label = paste0(n, "\n(", sprintf("%.1f", percentage), "%)")),
            vjust = -0.5, size = 5, fontface = "bold", color = "#2C3E50") +
  scale_fill_identity() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15)),
                     breaks = seq(0, 100, 20)) +
  labs(
    title = "Payment Compliance Status",
    subtitle = "Makeni Tax Collection - Enforcement Analysis",
    x = NULL,
    y = "Number of Cases",
    caption = paste0("Total reminder letters delivered = ", sum(status_summary$n))
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0.5, color = "#2C3E50"),
    plot.subtitle = element_text(size = 13, hjust = 0.5, color = "#7F8C8D", margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "#95A5A6", hjust = 1),
    axis.text.x = element_text(size = 11, angle = 0, hjust = 0.5, color = "#34495E"),
    axis.text.y = element_text(size = 11, color = "#34495E"),
    axis.title.y = element_text(size = 12, face = "bold", margin = margin(r = 10)),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  )

# Display plot
print(p1)

# ------------------------------------------------------------------------------
# Alternative: Horizontal bar chart (better for labels)
# ------------------------------------------------------------------------------
p2 <- ggplot(status_summary, aes(x = n, y = reorder(status_label, n), fill = fill_color)) +
  geom_bar(stat = "identity", width = 0.7) +
  geom_text(aes(label = paste0(n, " (", sprintf("%.1f", percentage), "%)")),
            hjust = -0.1, size = 5, fontface = "bold", color = "#2C3E50") +
  scale_fill_identity() +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15)),
                     breaks = seq(0, 100, 20)) +
  labs(
    title = "Payment Compliance Status",
    subtitle = "Makeni Tax Collection - Enforcement Analysis",
    x = "Number of Cases",
    y = NULL,
    caption = paste0("Total reminder letters delivered = ", sum(status_summary$n))
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, hjust = 0.5, color = "#2C3E50"),
    plot.subtitle = element_text(size = 13, hjust = 0.5, color = "#7F8C8D", margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "#95A5A6", hjust = 1),
    axis.text = element_text(size = 11, color = "#34495E"),
    axis.title.x = element_text(size = 12, face = "bold", margin = margin(t = 10)),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  )

print(p2)

# ------------------------------------------------------------------------------
# Breakdown for "Paid after enforcement" (status == 2)
# ------------------------------------------------------------------------------
p3 <- ggplot(status2_breakdown, aes(x = n, y = reorder(group, n), fill = group)) +
  geom_bar(stat = "identity", width = 0.7) +
  geom_text(aes(label = paste0(n, " (", sprintf("%.1f", percentage), "%)")),
            hjust = -0.1, size = 4.5, fontface = "bold", color = "#2C3E50") +
  scale_fill_manual(values = c(
    # Orange variations for delivery types (dark to light)
    setNames(c("#D35400", "#E67E22", "#F39C12", "#F8C471"), 
             unique(status2_breakdown$group[status2_breakdown$category == "By Delivery Type"])),
    # Blue variations for banks (dark to light)
    setNames(c("#1B4F72", "#2874A6", "#3498DB", "#7FB3D5"), 
             unique(status2_breakdown$group[status2_breakdown$category == "By Bank"]))
  )) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.2)),
                     breaks = seq(0, 10, 2)) +
  facet_wrap(~category, scales = "free_y", ncol = 1) +
  labs(
    title = "Breakdown: Paid After Enforcement",
    subtitle = "Analysis by Delivery Type and Bank",
    x = "Number of Cases",
    y = NULL,
    caption = paste0("Total paid after enforcement = ", sum(status2_breakdown$n[status2_breakdown$category == "By Delivery Type"]))
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", size = 17, hjust = 0.5, color = "#2C3E50"),
    plot.subtitle = element_text(size = 12, hjust = 0.5, color = "#7F8C8D", margin = margin(b = 15)),
    plot.caption = element_text(size = 10, color = "#95A5A6", hjust = 1),
    axis.text = element_text(size = 11, color = "#34495E"),
    axis.title.x = element_text(size = 11, face = "bold", margin = margin(t = 10)),
    strip.text = element_text(size = 12, face = "bold", color = "#2C3E50"),
    strip.background = element_rect(fill = "#ECF0F1", color = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.margin = margin(20, 20, 20, 20)
  )

print(p3)

# ------------------------------------------------------------------------------
# Save plots
# ------------------------------------------------------------------------------
ggsave(file.path(output_path, "makeni_compliance_vertical.png"), 
       plot = p1, width = 10, height = 7, dpi = 300, bg = "white")

ggsave(file.path(output_path, "makeni_compliance_horizontal.png"), 
       plot = p2, width = 10, height = 7, dpi = 300, bg = "white")

ggsave(file.path(output_path, "makeni_compliance_status2_breakdown.png"), 
       plot = p3, width = 10, height = 8, dpi = 300, bg = "white")

# ------------------------------------------------------------------------------
# Print summary statistics
# ------------------------------------------------------------------------------
cat("\n=== COMPLIANCE SUMMARY ===\n")
print(status_summary %>% select(status_label, n, percentage))
cat("\nCompliance rate (paid before/after enforcement):", 
    sprintf("%.1f%%", sum(status_summary$percentage[status_summary$status != 0])), "\n")