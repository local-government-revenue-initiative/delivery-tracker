################################################################################
# VISUAL ANALYSIS OF PROPERTY TAX PAYMENTS
# Kenema City Council, Sierra Leone (2021-2025)
# 
# Author: Robin Benabid Jegaden
# Date: January 2026
# 
# This script creates publication-quality visualizations using modern R packages
################################################################################

# Load required packages
library(tidyverse)      # Data manipulation and ggplot2
library(lubridate)      # Date handling
library(scales)         # Scale functions for ggplot2
library(patchwork)      # Combine multiple plots
library(viridis)        # Color palettes
library(ggridges)       # Ridge plots
library(plotly)         # Interactive plots
library(gganimate)      # Animated plots
library(ggthemes)       # Additional themes
library(treemapify)     # Treemap visualizations
library(ggrepel)        # Better label placement
library(cowplot)        # Publication-ready plots
library(sf)             # Spatial data handling
library(nnet)           # Multinomial logistic regression
library(broom)          # Tidy model outputs
library(stargazer)      # Model summary tables
library(ggridges)       # Ridge plots

# Set global theme for all plots
theme_set(theme_minimal(base_size = 12, base_family = "sans"))

# Custom color palette
kcc_colors <- c(
  primary = "#2C3E50",      # Navy
  secondary = "#E74C3C",    # Red
  tertiary = "#27AE60",     # Green
  quaternary = "#F39C12",   # Orange
  quinary = "#8E44AD"       # Purple
)

# Custom theme for consistency
theme_kcc <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = kcc_colors["primary"]),
      plot.subtitle = element_text(size = 11, color = "grey40", margin = margin(b = 10)),
      plot.caption = element_text(size = 8, color = "grey50", hjust = 0),
      axis.title = element_text(size = 10, face = "bold"),
      axis.text = element_text(size = 9),
      legend.position = "right",
      legend.title = element_text(size = 10, face = "bold"),
      legend.text = element_text(size = 9),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}

################################################################################
# DATA LOADING AND PREPARATION
################################################################################

# Load the data from Stata file
# Option 1: From .dta file
library(haven)
df <- read_dta("D:/Dropbox/LoGRI/Sierra_Leone/data/3_Final/revenue_reporting/Kenema/KCC_revenue_analysis.dta")

# Option 2: From CSV (if exported)
# df <- read_csv("your_file.csv")

# Data cleaning and preparation
df_clean <- df %>%
  mutate(
    # Convert Stata date to R date (Stata dates are days since Jan 1, 1960)
    date = as.Date(date, origin = "1960-01-01"),
    
    # Extract temporal variables
    year = year(date),
    month = month(date, label = TRUE, abbr = TRUE),
    month_num = month(date),
    week = week(date),
    quarter = quarter(date),
    year_month = floor_date(date, "month"),
    year_week = floor_date(date, "week"),
    day_of_year = yday(date),
    
    # Clean categorical variables
    bank = str_trim(bank),
    #community = str_trim(community),
    #ward = str_trim(ward),
    
    # Create payment categories
    payment_category = case_when(
      payment < 0 ~ "Negative (Refund?)",
      payment <= 100 ~ "0-100 Le",
      payment <= 500 ~ "100-500 Le",
      payment <= 1000 ~ "500-1,000 Le",
      payment <= 5000 ~ "1,000-5,000 Le",
      payment <= 10000 ~ "5,000-10,000 Le",
      TRUE ~ "10,000+ Le"
    ),
    payment_category = factor(payment_category, levels = c(
      "Negative (Refund?)", "0-100 Le", "100-500 Le", "500-1,000 Le",
      "1,000-5,000 Le", "5,000-10,000 Le", "10,000+ Le"
    ))
  ) %>%
  filter(!is.na(payment))  # Remove missing payments if any

# Create output directory for plots
dir.create("plots", showWarnings = FALSE)

################################################################################
# PART 1: TEMPORAL EVOLUTION - ANNUAL ANALYSIS
################################################################################

cat("Creating annual visualizations...\n")
# 1.1 Annual Revenue - Modern Bar Chart with Trend
annual_summary <- df_clean %>%
  group_by(year, type) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    median_payment = median(payment, na.rm = TRUE),
    .groups = "drop"
  )
p1 <- ggplot(annual_summary, aes(x = factor(year), y = total_revenue / 1e6, fill = type)) +
  geom_col(alpha = 0.8, width = 0.7, position = "dodge") +
  geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
            vjust = -0.5, size = 4, fontface = "bold", position = position_dodge(width = 0.7)) +
  scale_fill_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Total Revenue by Year",
    subtitle = "Kenema City Council Property Tax Collection (2024-2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database | Note: Data through December 12, 2025"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/01_annual_revenue.png", p1, width = 10, height = 6, dpi = 300)

# 1.1 Weekly Time Series - Revenue by Year
# Create plots for each year
years <- 2024:2025

for (y in years) {
  # Weekly summary for specific year
  weekly_summary_year <- df_clean %>%
    filter(year == y) %>%
    group_by(year_week, type) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    )
  
  p_weekly <- ggplot(weekly_summary_year, aes(x = year_week, y = total_revenue / 1e6, color = type, fill = type, group = type)) +
    geom_area(alpha = 0.3, position = "identity") +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
    scale_color_brewer(palette = "Dark2") +
    scale_fill_brewer(palette = "Dark2") +
    scale_x_date(date_breaks = "1 month", date_labels = "%b") +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
    labs(
      title = paste0("Weekly Revenue Evolution - ", y),
      subtitle = "Trend analysis with LOESS smoothing by week",
      x = NULL,
      y = "Total Revenue (Millions Le)",
      caption = "Source: KCC Property Tax Database | Dashed line shows smoothed trend"
    ) +
    theme_kcc()
  
  ggsave(paste0("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/04_weekly_revenue_series_", y, ".png"), 
         p_weekly, width = 14, height = 6, dpi = 300)
}

# 1.2 Annual Payment Count
p2 <- ggplot(annual_summary, aes(x = factor(year), y = payment_count / 1000, fill = type)) +
  geom_col(alpha = 0.8, width = 0.7, position = "dodge") +
  geom_text(aes(label = paste0(round(payment_count / 1000, 1), "K")),
            vjust = -0.5, size = 4, fontface = "bold", position = position_dodge(width = 0.7)) +
  scale_fill_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_number(suffix = "K", scale = 1),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Number of Payments by Year",
    subtitle = "Annual transaction volume trends",
    x = NULL,
    y = "Number of Payments (Thousands)",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/02_annual_payment_count.png", p2, width = 10, height = 6, dpi = 300)

# 1.3 Average Payment by Type Over Time
p3 <- ggplot(annual_summary, aes(x = factor(year), y = avg_payment / 1000, color = type, group = type)) +
  geom_line(size = 1.2) +
  geom_point(size = 3) +
  geom_text(aes(label = paste0(round(avg_payment / 1000, 2), "K")),
            vjust = -1, size = 3.5, fontface = "bold") +
  scale_color_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_number(suffix = "K", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Average Payment by Type Over Time",
    subtitle = "Evolution of mean payment amounts (2024-2025)",
    x = NULL,
    y = "Average Payment (Thousands Le)",
    color = "Type",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/03_avg_payment_by_type.png", p3, width = 10, height = 6, dpi = 300)

################################################################################
# PART 2: TEMPORAL EVOLUTION - MONTHLY ANALYSIS
################################################################################

cat("Creating monthly time series visualizations...\n")
# 2.1 Monthly Time Series - Revenue
monthly_summary <- df_clean %>%
  group_by(year_month, type) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  )
p4 <- ggplot(monthly_summary, aes(x = year_month, y = total_revenue / 1e6, color = type, fill = type, group = type)) +
  geom_area(alpha = 0.3, position = "identity") +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
  scale_color_brewer(palette = "Dark2") +
  scale_fill_brewer(palette = "Dark2") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Monthly Revenue Evolution",
    subtitle = "Trend analysis with LOESS smoothing (January 2024 - December 2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database | Dashed line shows smoothed trend"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/04_monthly_revenue_series.png", p4, width = 14, height = 6, dpi = 300)

# 2.2 Monthly Time Series - Payment Count
monthly_summary <- df_clean %>%
  group_by(year_month, type) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  )

p5 <- ggplot(monthly_summary, aes(x = year_month, y = payment_count, color = type, group = type)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
  scale_color_brewer(palette = "Dark2") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Monthly Payment Count Evolution",
    subtitle = "Transaction volume trends over time",
    x = NULL,
    y = "Number of Payments",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/05_monthly_count_series.png", p5, width = 14, height = 6, dpi = 300)


cat("Creating budget vs actual revenue comparison for 2025...\n")
# Budget targets for 2025 - UPDATE THESE VALUES FOR KENEMA
budget_2025 <- data.frame(
  type = c("Property Tax", "Business License"),
  budget = c(40036397.69, 14055715.39)  # NOTE: Update these with actual KCC budget targets
)

# Calculate actual revenue collected in 2025
actual_2025 <- df_clean %>%
  filter(year == 2025) %>%
  group_by(type) %>%
  summarise(actual = sum(payment, na.rm = TRUE), .groups = "drop") %>%
  mutate(type = case_when(
    type == "property" ~ "Property Tax",
    type == "business" ~ "Business License",
    TRUE ~ type
  ))

# Combine budget and actual
budget_comparison <- budget_2025 %>%
  left_join(actual_2025, by = "type") %>%
  mutate(
    actual = replace_na(actual, 0),
    remaining = budget - actual,
    pct_achieved = (actual / budget) * 100,
    status = ifelse(pct_achieved >= 100, "Exceeded", "Below Target")
  )

# Add total row
budget_comparison_with_total <- budget_comparison %>%
  bind_rows(
    budget_comparison %>%
      summarise(
        type = "Total",
        budget = sum(budget),
        actual = sum(actual),
        remaining = sum(remaining),
        pct_achieved = (sum(actual) / sum(budget)) * 100,
        status = ifelse(pct_achieved >= 100, "Exceeded", "Below Target")
      )
  ) %>%
  mutate(type = factor(type, levels = c("Property Tax", "Business License", "Total")))

# Print summary
cat("\n=== BUDGET vs ACTUAL (2025) ===\n")
print(budget_comparison_with_total)

# Create visualization
budget_long <- budget_comparison_with_total %>%
  select(type, budget, actual, remaining) %>%
  pivot_longer(cols = c(actual, remaining), names_to = "category", values_to = "amount") %>%
  mutate(category = factor(category, levels = c("remaining", "actual"),
                           labels = c("Remaining", "Collected")))

p_budget <- ggplot(budget_long, aes(x = type, y = amount / 1e6, fill = category)) +
  geom_col(alpha = 0.9, width = 0.6) +
  geom_text(data = budget_comparison_with_total,
            aes(x = type, y = (actual / 1e6) / 2, label = paste0(format(round(actual / 1e6, 2), big.mark = ","), "M")),
            fontface = "bold", size = 4, color = "white", inherit.aes = FALSE) +
  geom_text(data = budget_comparison_with_total, 
            aes(x = type, y = budget / 1e6, label = paste0(round(pct_achieved, 1), "%\nachieved")),
            vjust = -0.5, fontface = "bold", size = 4, inherit.aes = FALSE) +
  geom_hline(data = budget_comparison_with_total, aes(yintercept = budget / 1e6), 
             linetype = "dashed", color = "black", linewidth = 0.8) +
  scale_fill_manual(values = c("Collected" = "#006400", "Remaining" = "#8B0000"),
                    name = NULL) +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "2025 Budget Performance: Actual vs Target",
    subtitle = "Revenue collected vs budget targets (January - December 2025)",
    x = NULL,
    y = "Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database | Dashed line = Budget target"
  ) +
  theme_kcc() +
  theme(legend.position = "top")
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/budget_vs_actual_2025.png", 
       p_budget, width = 12, height = 7, dpi = 300)

# 4. Year-end projection based on current pace
# Determine current month from the data
current_month <- df_clean %>%
  filter(year == 2025) %>%
  summarise(max_month = max(month_num)) %>%
  pull(max_month)

months_elapsed <- current_month
months_remaining <- 12 - current_month

projection <- budget_comparison %>%
  mutate(
    monthly_avg = actual / months_elapsed,
    projected_year_end = actual + (monthly_avg * months_remaining),
    projected_pct = (projected_year_end / budget) * 100,
    gap = budget - projected_year_end
  )

p_projection <- projection %>%
  select(type, actual, projected_year_end, budget) %>%
  pivot_longer(cols = -type, names_to = "category", values_to = "amount") %>%
  mutate(category = factor(category, 
                           levels = c("actual", "projected_year_end", "budget"),
                           labels = c(paste0("Collected (Jan-", month.abb[current_month], ")"), 
                                      "Projected Year-End", 
                                      "Budget Target"))) %>%
  ggplot(aes(x = category, y = amount / 1e6, fill = category)) +
  geom_col(alpha = 0.9) +
  geom_text(aes(label = paste0(format(round(amount / 1e6, 2), big.mark = ","), "M")),
            vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("#006400", "#FFD700", "#8B0000"),
                    guide = "none") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  facet_wrap(~type, scales = "free_y") +
  labs(
    title = "Year-End Revenue Projection (2025)",
    subtitle = paste0("Based on average monthly collection rate (January - ", month.name[current_month], ")"),
    x = NULL,
    y = "Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/budget_projection_2025.png", 
       p_projection, width = 12, height = 7, dpi = 300)

################################################################################
# PART 3: SEASONALITY ANALYSIS
################################################################################

cat("Creating seasonality visualizations...\n")
# 3.1 Seasonality - All months combined
seasonal_summary <- df_clean %>%
  group_by(month, type) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(month)

p7 <- ggplot(seasonal_summary, aes(x = month, y = total_revenue / 1e6, fill = total_revenue)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
            vjust = -0.5, size = 3.5, fontface = "bold") +
  scale_fill_gradient(low = kcc_colors["primary"], high = kcc_colors["secondary"]) +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  facet_wrap(~type, scales = "free_y") +
  labs(
    title = "Revenue Seasonality Pattern",
    subtitle = "Total revenue by month (all years combined, 2024-2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/07_seasonality_revenue.png", p7, width = 12, height = 6, dpi = 300)


# 3.2 Heatmap - Year × Month
heatmap_data <- df_clean %>%
  group_by(year, month_num) %>%
  summarise(total_revenue = sum(payment, na.rm = TRUE), .groups = "drop")

p8 <- ggplot(heatmap_data, aes(x = month_num, y = factor(year), fill = total_revenue / 1e6)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = round(total_revenue / 1e6, 2)), 
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_viridis_c(option = "plasma", name = "Revenue\n(Millions Le)",
                       labels = label_number(scale = 1)) +
  scale_x_continuous(breaks = 1:12, 
                     labels = month.abb,
                     expand = c(0, 0)) +
  scale_y_discrete(expand = c(0, 0)) +
  labs(
    title = "Revenue Heatmap: Year × Month",
    subtitle = "Identify peak collection periods and trends",
    x = NULL,
    y = NULL,
    caption = "Source: KCC Property Tax Database | Note: 2025 data through December 12"
  ) +
  theme_kcc() +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(angle = 0)
  )

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/08_heatmap_year_month.png", p8, width = 12, height = 6, dpi = 300)

################################################################################
# PART 6: BANK ANALYSIS
# Kenema City Council Revenue Analysis
################################################################################

cat("Creating bank visualizations...\n")
# 6.1 Bank Performance with Market Share Donut - Combined
bank_summary <- df_clean %>%
  filter(!is.na(bank)) %>%
  group_by(bank) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_revenue)) %>%
  mutate(percentage = total_revenue / sum(total_revenue) * 100)

# Create consistent color palette
bank_colors <- viridis::viridis(n = nrow(bank_summary), option = "viridis")
names(bank_colors) <- bank_summary$bank

p16_bar <- bank_summary %>%
  mutate(bank = fct_reorder(bank, total_revenue)) %>%
  ggplot(aes(x = total_revenue / 1e6, y = bank, fill = bank)) +
  geom_col(alpha = 0.9, show.legend = FALSE) +
  geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
            hjust = -0.2, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = bank_colors) +
  scale_x_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Revenue Collected by Bank",
    subtitle = "Total collection per banking partner (2024-2025)",
    x = "Total Revenue (Millions Le)",
    y = NULL
  ) +
  theme_kcc()

# Donut chart for market share
p16_donut <- bank_summary %>%
  mutate(ymax = cumsum(percentage),
         ymin = c(0, head(ymax, n = -1)),
         labelPosition = (ymax + ymin) / 2,
         label = paste0(bank, "\n", round(percentage, 1), "%")) %>%
  ggplot(aes(ymax = ymax, ymin = ymin, xmax = 4, xmin = 3, fill = bank)) +
  geom_rect(alpha = 0.9) +
  geom_text(aes(x = 4.5, y = labelPosition, label = label), size = 3.5, fontface = "bold") +
  scale_fill_manual(values = bank_colors) +
  coord_polar(theta = "y") +
  xlim(c(2, 4.5)) +
  labs(
    title = "Market Share by Bank",
    subtitle = "Percentage of total revenue"
  ) +
  theme_void() +
  theme(legend.position = "none",
        plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
        plot.subtitle = element_text(hjust = 0.5, size = 11))

# Combine both plots
p16_combined <- p16_bar + p16_donut + 
  plot_annotation(
    caption = "Source: KCC Property Tax Database",
    theme = theme(plot.caption = element_text(hjust = 1, size = 9))
  )
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/16_banks_revenue_combined.png", 
       p16_combined, width = 16, height = 8, dpi = 300)

# 6.2 Bank Monthly Evolution - Payment count excluding Other and KCC
bank_monthly_count <- df_clean %>%
  filter(!bank %in% c("Other", "KCC")) %>%
  group_by(bank, year_month) %>%
  summarise(payment_count = n(), .groups = "drop")

p17 <- ggplot(bank_monthly_count, aes(x = year_month, y = payment_count, color = bank)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Dark2", name = "Bank") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Monthly Payment Count Evolution by Bank",
    subtitle = "Number of payments over time (2024-2025)",
    x = NULL,
    y = "Number of Payments",
    caption = "Source: KCC Property Tax Database | Excluding Other and KCC"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/17_banks_monthly_payment_count.png", p17, width = 14, height = 7, dpi = 300)

# 6.3 Bank Monthly Evolution - Cumulative revenue excluding Other and KCC
bank_monthly_cumulative <- df_clean %>%
  filter(!bank %in% c("Other", "KCC")) %>%
  group_by(bank, year_month) %>%
  summarise(monthly_revenue = sum(payment, na.rm = TRUE), .groups = "drop") %>%
  group_by(bank) %>%
  arrange(year_month) %>%
  mutate(cumulative_revenue = cumsum(monthly_revenue)) %>%
  ungroup()

p17_cumulative <- ggplot(bank_monthly_cumulative, aes(x = year_month, y = cumulative_revenue / 1e6, color = bank)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Dark2", name = "Bank") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Cumulative Revenue Evolution by Bank",
    subtitle = "Total accumulated revenue over time (2024-2025)",
    x = NULL,
    y = "Cumulative Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database | Excluding Other and KCC"
  ) +
  theme_kcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/17_banks_cumulative_revenue.png", 
       p17_cumulative, width = 14, height = 7, dpi = 300)

cat("Bank analysis visualizations completed.\n")

################################################################################
# PART 8: PAYMENT DISTRIBUTION ANALYSIS
# Kenema City Council Revenue Analysis
################################################################################

cat("Creating payment distribution visualizations...\n")

# 8.1 Payment Distribution - Histogram with log scale
p21 <- df_clean %>%
  filter(payment > 0, payment < 50000) %>%
  ggplot(aes(x = payment)) +
  geom_histogram(aes(y = after_stat(density)), bins = 100, 
                 fill = kcc_colors["primary"], alpha = 0.7, color = "white") +
  geom_density(color = kcc_colors["secondary"], linewidth = 1.5) +
  scale_x_log10(labels = label_comma()) +
  labs(
    title = "Payment Amount Distribution",
    subtitle = "Histogram with density overlay (0 < payment < 50,000 Le, log scale)",
    x = "Payment Amount (Le, log scale)",
    y = "Density",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/21_payment_distribution.png", p21, width = 12, height = 7, dpi = 300)

# 8.2 Payment Categories Over Time
payment_cat_time <- df_clean %>%
  filter(payment > 0) %>%
  group_by(year_month, payment_category) %>%
  summarise(payment_count = n(), .groups = "drop")

p22 <- ggplot(payment_cat_time, aes(x = year_month, y = payment_count, 
                                    fill = payment_category)) +
  geom_area(alpha = 0.8, position = "stack") +
  scale_fill_viridis_d(option = "turbo", name = "Payment\nCategory") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Payment Volume by Category Over Time",
    subtitle = "Stacked area chart showing transaction size distribution",
    x = NULL,
    y = "Number of Payments",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/22_payment_categories_time.png", p22, width = 14, height = 7, dpi = 300)

################################################################################
# PART 9: ADVANCED ANALYTICS
################################################################################

# 9.3 Cumulative Revenue by Year
cumulative_data <- df_clean %>%
  group_by(year) %>%
  arrange(date) %>%
  mutate(
    day_of_year = yday(date),
    cumulative_revenue = cumsum(payment)
  ) %>%
  ungroup()

p27 <- ggplot(cumulative_data, aes(x = day_of_year, y = cumulative_revenue / 1e6,
                                   color = factor(year))) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  scale_color_viridis_d(option = "plasma", name = "Year") +
  scale_x_continuous(breaks = c(1, 91, 182, 274, 365),
                     labels = c("Jan 1", "Apr 1", "Jul 1", "Oct 1", "Dec 31")) +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Cumulative Revenue Progression by Year",
    subtitle = "Comparing collection pace across years",
    x = "Day of Year",
    y = "Cumulative Revenue (Millions Le)",
    caption = "Source: KCC Property Tax Database | Note: 2025 data through December 12"
  ) +
  theme_kcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/27_cumulative_revenue.png", p27, width = 14, height = 7, dpi = 300)


# 9.4. Chi-square test - Categorized payment vs Bank
df_chi <- df_clean %>%
  filter(!is.na(bank), !is.na(payment)) %>%
  mutate(payment_quartile = cut(payment, 
                                breaks = quantile(payment, probs = 0:4/4),
                                labels = c("Q1 (Low)", "Q2", "Q3", "Q4 (High)"),
                                include.lowest = TRUE))

chi_test <- chisq.test(table(df_chi$payment_quartile, df_chi$bank))
print(chi_test)

# Cross-tabulation: % by payment quartile
cross_tab <- df_chi %>%
  group_by(payment_quartile, bank) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(payment_quartile) %>%
  mutate(pct = n / sum(n) * 100) %>%
  select(payment_quartile, bank, pct) %>%
  pivot_wider(names_from = bank, values_from = pct, values_fill = 0)
print(cross_tab)

# Visualization of cross-tabulation
p3 <- df_chi %>%
  group_by(payment_quartile, bank) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(payment_quartile) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ggplot(aes(x = payment_quartile, y = pct, fill = bank)) +
  geom_col(position = "fill", alpha = 0.9) +
  geom_text(aes(label = ifelse(pct > 3, paste0(round(pct, 1), "%"), "")),
            position = position_fill(vjust = 0.5), size = 3, fontface = "bold", color = "white") +
  scale_fill_brewer(palette = "Dark2", name = "Bank") +
  scale_y_continuous(labels = label_percent()) +
  labs(
    title = "Bank Preferences by Payment Quartile",
    subtitle = "Distribution of bank usage across income levels",
    x = "Payment Quartile",
    y = "Percentage",
    caption = "Source: KCC Property Tax Database"
  ) +
  theme_kcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/bank_by_payment_quartile.png", 
       p3, width = 12, height = 7, dpi = 300)


# 9.5. Simple linear regression (Bank encoded as factor)
# NOTE: Update the bank factor levels based on actual banks operating in Kenema
# First, check which banks exist in your data:
cat("\nBanks present in Kenema data:\n")
print(unique(df_clean$bank))

# Create factor with banks present in the data
# Adjust the levels below based on your actual data
df_reg <- df_clean %>%
  filter(!is.na(bank), !is.na(payment)) %>%
  mutate(bank_factor = factor(bank))

# Get the most common bank to use as reference
reference_bank <- df_clean %>%
  filter(!is.na(bank)) %>%
  count(bank, sort = TRUE) %>%
  slice(1) %>%
  pull(bank)

cat(paste0("\nUsing ", reference_bank, " as reference category\n"))

# Relevel factor to set reference category
df_reg <- df_reg %>%
  mutate(bank_factor = relevel(bank_factor, ref = reference_bank))

# Regression: Payment explained by Bank
model <- lm(payment ~ bank_factor, data = df_reg)
summary(model)

# Get bank names for labels (excluding reference)
bank_levels <- levels(df_reg$bank_factor)
covariate_labels <- c(bank_levels[-1], paste0("Constant (", reference_bank, ")"))

stargazer(model, 
          type = "text",
          title = "Regression: Payment Amount by Bank Choice",
          dep.var.labels = "Payment Amount (Le)",
          covariate.labels = covariate_labels,
          notes = paste0("Reference category: ", reference_bank),
          notes.align = "l",
          out = "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/regression_table.txt")

# Save as HTML
stargazer(model, 
          type = "html",
          title = "Regression: Payment Amount by Bank Choice",
          dep.var.labels = "Payment Amount (Le)",
          covariate.labels = covariate_labels,
          notes = paste0("Reference category: ", reference_bank, ". *** p<0.01, ** p<0.05, * p<0.1"),
          notes.align = "l",
          out = "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Kenema/regression_table.html")

cat("\nPayment distribution and advanced analytics completed.\n")