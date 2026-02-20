################################################################################
# VISUAL ANALYSIS OF PROPERTY TAX PAYMENTS
# Freetown City Council, Sierra Leone (2021-2025)
# 
# Author: Robin Benabid Jegaden
# Date: October 2025
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
fcc_colors <- c(
  primary = "#2C3E50",      # Navy
  secondary = "#E74C3C",    # Red
  tertiary = "#27AE60",     # Green
  quaternary = "#F39C12",   # Orange
  quinary = "#8E44AD"       # Purple
)

# Custom theme for consistency
theme_fcc <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = fcc_colors["primary"]),
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
df <- read_dta("D:/Dropbox/LoGRI/Sierra_Leone/data/3_Final/revenue_reporting/Freetown/FCC_revenue_analysis.dta")

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
    subtitle = "Freetown City Council Property Tax Collection (2021-2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database | Note: Data through December 12, 2025"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/01_annual_revenue.png", p1, width = 10, height = 6, dpi = 300)

# 1.1 Weekly Time Series - Revenue by Year
# Créer les graphiques pour chaque année
years <- 2021:2025

for (y in years) {
  # Weekly summary pour l'année spécifique
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
      caption = "Source: FCC Property Tax Database | Dashed line shows smoothed trend"
    ) +
    theme_fcc()
  
  ggsave(paste0("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/04_weekly_revenue_series_", y, ".png"), 
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
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/02_annual_payment_count.png", p2, width = 10, height = 6, dpi = 300)

# 1.3 Average Payment by Type Over Time
p3 <- ggplot(annual_summary, aes(x = factor(year), y = avg_payment / 1000, color = type, group = type)) +
  geom_line(size = 1.2) +
  geom_point(size = 3) +
  geom_text(aes(label = paste0(round(avg_payment / 1000, 1), "K")),
            vjust = -1, size = 3.5, fontface = "bold") +
  scale_color_brewer(palette = "Dark2") +
  scale_y_continuous(labels = label_number(suffix = "K", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Average Payment by Type Over Time",
    subtitle = "Evolution of mean payment amounts (2021-2025)",
    x = NULL,
    y = "Average Payment (Thousands Le)",
    color = "Type",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/03_avg_payment_by_type.png", p3, width = 10, height = 6, dpi = 300)

################################################################################
# PART 2: TEMPORAL EVOLUTION - MONTHLY ANALYSIS
################################################################################

#cat("Creating monthly time series visualizations...\n")

# 2.1 Monthly Time Series - Revenue
#monthly_summary <- df_clean %>%
#  group_by(year_month) %>%
#  summarise(
#    total_revenue = sum(payment, na.rm = TRUE),
#    payment_count = n(),
#    avg_payment = mean(payment, na.rm = TRUE),
#    .groups = "drop"
#  )
#
#p4 <- ggplot(monthly_summary, aes(x = year_month, y = total_revenue / 1e6)) +
#  geom_area(fill = fcc_colors["primary"], alpha = 0.3) +
#  geom_line(color = fcc_colors["primary"], linewidth = 1) +
#  geom_point(color = fcc_colors["primary"], size = 2) +
#  geom_smooth(method = "loess", se = TRUE, color = fcc_colors["secondary"], 
#              linewidth = 0.8, linetype = "dashed", alpha = 0.2) +
#  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
#  scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
# labs(
#   title = "Monthly Revenue Evolution",
#    subtitle = "Trend analysis with LOESS smoothing (January 2021 - December 2025)",
#    x = NULL,
#    y = "Total Revenue (Millions Le)",
#    caption = "Source: FCC Property Tax Database | Dashed line shows smoothed trend"
#  ) +
#  theme_fcc()

#ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/04_monthly_revenue_series_RDN.png", p4, width = 14, height = 6, dpi = 300)

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
    subtitle = "Trend analysis with LOESS smoothing (January 2021 - December 2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database | Dashed line shows smoothed trend"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/04_monthly_revenue_series.png", p4, width = 14, height = 6, dpi = 300)

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
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/05_monthly_count_series.png", p5, width = 14, height = 6, dpi = 300)


cat("Creating budget vs actual revenue comparison for 2025...\n")
# Budget targets for 2025
budget_2025 <- data.frame(
  type = c("Property Tax", "Business License"),
  budget = c(40036397.69, 14055715.39)
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
    caption = "Source: FCC Property Tax Database | Dashed line = Budget target"
  ) +
  theme_fcc() +
  theme(legend.position = "top")
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/budget_vs_actual_2025.png", 
       p_budget, width = 12, height = 7, dpi = 300)

# 4. Projection pour fin d'année basée sur le rythme actuel
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
                           labels = c("Collected (Jan-Oct)", "Projected Year-End", "Budget Target"))) %>%
  ggplot(aes(x = category, y = amount / 1e6, fill = category)) +
  geom_col(alpha = 0.9) +
  geom_text(aes(label = paste0(format(round(amount / 1e6, 2), big.mark = ","), "M")),
            vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("Collected (Jan-Oct)" = "#006400", 
                               "Projected Year-End" = "#FFD700", 
                               "Budget Target" = "#8B0000"),
                    guide = "none") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  facet_wrap(~type, scales = "free_y") +
  labs(
    title = "Year-End Revenue Projection (2025)",
    subtitle = "Based on average monthly collection rate (January - December)",
    x = NULL,
    y = "Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/budget_projection_2025.png", 
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
  scale_fill_gradient(low = fcc_colors["primary"], high = fcc_colors["secondary"]) +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  facet_wrap(~type, scales = "free_y") +
  labs(
    title = "Revenue Seasonality Pattern",
    subtitle = "Total revenue by month (all years combined, 2021-2025)",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/07_seasonality_revenue.png", p7, width = 12, height = 6, dpi = 300)


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
    caption = "Source: FCC Property Tax Database | Note: 2025 data through December 12"
  ) +
  theme_fcc() +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(angle = 0)
  )

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/08_heatmap_year_month.png", p8, width = 12, height = 6, dpi = 300)

################################################################################
# PART 4: GEOGRAPHIC ANALYSIS - WARDS
################################################################################

cat("Creating ward visualizations...\n")
# 4.1 Top 10 and Bottom 10 Wards by Revenue - Lollipop chart
ward_summary <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_revenue))
top_bottom_wards <- bind_rows(
  ward_summary %>% slice_head(n = 10) %>% mutate(category = "Top 10"),
  ward_summary %>% slice_tail(n = 10) %>% mutate(category = "Bottom 10")
)
p10 <- top_bottom_wards %>%
  mutate(ward = fct_reorder(ward, total_revenue),
         category = factor(category, levels = c("Top 10", "Bottom 10"))) %>%
  ggplot(aes(x = total_revenue / 1e6, y = ward, color = category)) +
  geom_segment(aes(x = 0, xend = total_revenue / 1e6, y = ward, yend = ward),
               linewidth = 1.5) +
  geom_point(size = 5) +
  geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
            hjust = -0.3, size = 3.5, fontface = "bold", color = "black") +
  scale_color_manual(values = c("Top 10" = "#006400", "Bottom 10" = "#8B0000")) +
  scale_x_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Top 10 and Bottom 10 Wards by Total Revenue",
    subtitle = "Period: 2021-2025",
    x = "Total Revenue (Millions Le)",
    y = NULL,
    color = NULL,
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank())
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/10_top_bottom_wards_revenue.png", p10, width = 10, height = 10, dpi = 300)

# 4.1 Top 10 and Bottom 10 Wards by Payment Count - Lollipop chart
ward_summary_count <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(payment_count))
top_bottom_wards_count <- bind_rows(
  ward_summary_count %>% slice_head(n = 10) %>% mutate(category = "Top 10"),
  ward_summary_count %>% slice_tail(n = 10) %>% mutate(category = "Bottom 10")
)
p10_count <- top_bottom_wards_count %>%
  mutate(ward = fct_reorder(ward, payment_count),
         category = factor(category, levels = c("Top 10", "Bottom 10"))) %>%
  ggplot(aes(x = payment_count, y = ward, color = category)) +
  geom_segment(aes(x = 0, xend = payment_count, y = ward, yend = ward),
               linewidth = 1.5) +
  geom_point(size = 5) +
  geom_text(aes(label = scales::comma(payment_count)),
            hjust = -0.3, size = 3.5, fontface = "bold", color = "black") +
  scale_color_manual(values = c("Top 10" = "#006400", "Bottom 10" = "#8B0000")) +
  scale_x_continuous(labels = label_comma(),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Top 10 and Bottom 10 Wards by Payment Count",
    subtitle = "Period: 2021-2025",
    x = "Number of Payments",
    y = NULL,
    color = NULL,
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank())
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/10_top_bottom_wards_payment_count.png", p10_count, width = 10, height = 10, dpi = 300)

# 4.3 Ward Evolution Over Years with % change in legend
ward_year_summary <- df_clean %>%
  filter(!is.na(ward)) %>%
  group_by(ward) %>%
  mutate(ward_total = sum(payment, na.rm = TRUE)) %>%
  ungroup() %>%
  filter(ward %in% (ward_summary %>% slice_head(n = 10) %>% pull(ward))) %>%
  group_by(ward, year) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  )

# Calculer le % de changement entre 2021 et 2025
ward_pct_change <- ward_year_summary %>%
  filter(year %in% c(2021, 2025)) %>%
  pivot_wider(names_from = year, values_from = total_revenue, names_prefix = "year_") %>%
  mutate(
    pct_change = ((year_2025 - year_2021) / year_2021) * 100,
    ward_label = paste0(ward, " (", ifelse(pct_change > 0, "+", ""), round(pct_change, 1), "%)")
  )

# Joindre avec les données complètes
ward_year_summary <- ward_year_summary %>%
  left_join(ward_pct_change %>% select(ward, ward_label), by = "ward")

p12 <- ggplot(ward_year_summary, aes(x = factor(year), y = total_revenue / 1e6, fill = ward_label)) +
  geom_col(position = "dodge", alpha = 0.9) +
  scale_fill_viridis_d(option = "turbo", name = "Ward (% change 2021-2025)") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Annual Revenue Evolution by Ward (Top 10)",
    subtitle = "Year-over-year comparison with % change from 2021 to 2025",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/12_ward_evolution_years.png", p12, width = 14, height = 7, dpi = 300)

# 4.3 Ward Evolution - Top 5 Ridgelineplot with monthly total revenue
# Préparer les données agrégées par mois pour le top 5
ward_top5_monthly <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  filter(ward %in% (ward_summary %>% slice_head(n = 5) %>% pull(ward))) %>%
  group_by(ward, year_month) %>%
  summarise(monthly_revenue = sum(payment, na.rm = TRUE), .groups = "drop")

# Calculer le % de changement entre 2021 et 2025 pour les labels
ward_pct_change_top5 <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  filter(ward %in% (ward_summary %>% slice_head(n = 5) %>% pull(ward))) %>%
  group_by(ward, year) %>%
  summarise(total_revenue = sum(payment, na.rm = TRUE), .groups = "drop") %>%
  filter(year %in% c(2021, 2025)) %>%
  pivot_wider(names_from = year, values_from = total_revenue, names_prefix = "year_") %>%
  mutate(
    pct_change = ((year_2025 - year_2021) / year_2021) * 100,
    ward_label = paste0(ward, " (", ifelse(pct_change > 0, "+", ""), round(pct_change, 1), "%)")
  )

# Joindre avec les données complètes
ward_top5_monthly <- ward_top5_monthly %>%
  left_join(ward_pct_change_top5 %>% select(ward, ward_label), by = "ward")

# Créer le ridgelineplot
p12_ridge <- ggplot(ward_top5_monthly, aes(x = year_month, y = ward_label, height = monthly_revenue / 1e6, fill = ward_label)) +
  geom_density_ridges(stat = "identity", scale = 2, alpha = 0.8, verbosity = 0) +
  scale_fill_viridis_d(option = "turbo", guide = "none") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b\n%Y") +
  labs(
    title = "Monthly Revenue Evolution by Ward (Top 5)",
    subtitle = "Monthly revenue patterns (2021-2025) | % change from 2021 to 2025",
    x = NULL,
    y = NULL,
    caption = "Source: FCC Property Tax Database | Height represents monthly revenue (Millions Le)"
  ) +
  theme_fcc() +
  theme(axis.text.y = element_text(vjust = 0))

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/12_ward_top5_ridgeplot_monthly.png", 
       p12_ridge, width = 14, height = 8, dpi = 300)

# 4.3 Ward Evolution Over Years - Bottom 10 with % change in legend
ward_year_summary_bottom <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  mutate(ward_total = sum(payment, na.rm = TRUE)) %>%
  ungroup() %>%
  filter(ward %in% (ward_summary %>% slice_tail(n = 10) %>% pull(ward))) %>%
  group_by(ward, year) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  )

# Calculer le % de changement entre 2021 et 2025
ward_pct_change_bottom <- ward_year_summary_bottom %>%
  filter(year %in% c(2021, 2025)) %>%
  pivot_wider(names_from = year, values_from = total_revenue, names_prefix = "year_") %>%
  mutate(
    pct_change = ((year_2025 - year_2021) / year_2021) * 100,
    ward_label = paste0(ward, " (", ifelse(pct_change > 0, "+", ""), round(pct_change, 1), "%)")
  )

# Joindre avec les données complètes
ward_year_summary_bottom <- ward_year_summary_bottom %>%
  left_join(ward_pct_change_bottom %>% select(ward, ward_label), by = "ward")

p12_bottom <- ggplot(ward_year_summary_bottom, aes(x = factor(year), y = total_revenue / 1e6, 
                                                   fill = ward_label)) +
  geom_col(position = "dodge", alpha = 0.9) +
  scale_fill_viridis_d(option = "turbo", name = "Ward (% change 2021-2025)") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Annual Revenue Evolution by Ward (Bottom 10)",
    subtitle = "Year-over-year comparison with % change from 2021 to 2025",
    x = NULL,
    y = "Total Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/12_ward_evolution_years_bottom10.png", p12_bottom, width = 14, height = 7, dpi = 300)

# 4.4 Bubble chart - Ward performance metrics
p13 <- ward_summary %>%
  ggplot(aes(x = payment_count, y = avg_payment, size = total_revenue, 
             fill = total_revenue)) +
  geom_point(alpha = 0.7, shape = 21, color = "white", stroke = 1) +
  geom_text_repel(aes(label = ward), size = 3, fontface = "bold", 
                  max.overlaps = 15) +
  scale_size_continuous(
    range = c(5, 25),
    name = "Total Revenue (Le)",
    labels = label_number(scale_cut = cut_short_scale())
  ) +
  scale_fill_viridis_c(
    option = "plasma",
    name = "Total Revenue (Le)",
    labels = label_number(scale_cut = cut_short_scale())
  ) +
  guides(
    size = guide_legend(order = 1),
    fill = guide_legend(order = 1)
  ) +
  scale_x_continuous(labels = label_comma()) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Ward Performance Metrics",
    subtitle = "Payment count vs. average payment (bubble size = total revenue)",
    x = "Number of Payments",
    y = "Average Payment (Le)",
    caption = "Source: FCC Property Tax Database | All wards shown"
  ) +
  theme_fcc()

ggsave(
  "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/13_ward_bubble_chart.png",
  p13, width = 12, height = 8, dpi = 300
)

cat("Creating violin plot for top 10 wards...\n")
# Identify top 10 wards by total revenue
top_10_wards <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(total_revenue = sum(payment, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(total_revenue)) %>%
  slice_head(n = 10) %>%
  pull(ward)

# Get individual payments for top 10 wards
top_wards_payments <- df_clean %>%
  filter(ward %in% top_10_wards) %>%
  mutate(ward = factor(ward, levels = top_10_wards))

# Create violin plot
p_violin_wards <- ggplot(top_wards_payments, aes(x = ward, y = payment / 1000, fill = ward)) +
  geom_violin(alpha = 0.8, show.legend = FALSE) +
  geom_boxplot(width = 0.1, alpha = 0.5, outlier.shape = NA, show.legend = FALSE) +
  scale_fill_viridis_d(option = "plasma") +
  scale_y_continuous(labels = label_number(suffix = "K", scale = 1)) +
  labs(
    title = "Payment Distribution by Ward (Top 10)",
    subtitle = "Violin plot showing payment distribution (2021-2025)",
    x = NULL,
    y = "Payment Amount (Thousands Le)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/violin_plot_top10_wards.png", 
       p_violin_wards, width = 12, height = 8, dpi = 300)

################################################################################
# PART 5: GEOGRAPHIC ANALYSIS - COMMUNITIES
################################################################################

cat("Creating wards per community visualization...\n")
# Compter le nombre de wards uniques par communauté
wards_per_community <- df_clean %>%
  filter(!is.na(community) & community != "", !is.na(ward) & ward != "") %>%
  group_by(community) %>%
  summarise(
    n_wards = n_distinct(ward),
    .groups = "drop"
  ) %>%
  arrange(desc(n_wards)) %>%
  mutate(ward_category = ifelse(n_wards == 1, "1 Ward", "Multiple Wards"))

p_wards_community <- wards_per_community %>%
  mutate(community = fct_reorder(community, n_wards)) %>%
  ggplot(aes(x = n_wards, y = community, fill = ward_category)) +
  geom_col(alpha = 0.9) +
  geom_text(aes(label = n_wards),
            hjust = -0.3, size = 3.5, fontface = "bold", color = "black") +
  scale_fill_manual(values = c("1 Ward" = "#006400", "Multiple Wards" = "#8B0000"), 
                    name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Number of Wards per Community",
    subtitle = "Distribution of wards across communities",
    x = "Number of Wards",
    y = NULL,
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank())

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/wards_per_community.png", 
       p_wards_community, width = 10, height = 12, dpi = 300)

# All Wards by Average Payment - Lollipop chart
ward_avg_summary <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(avg_payment))
p_ward_avg <- ward_avg_summary %>%
  mutate(ward = fct_reorder(ward, avg_payment)) %>%
  ggplot(aes(x = avg_payment / 1000, y = ward, color = avg_payment)) +
  geom_segment(aes(x = 0, xend = avg_payment / 1000, y = ward, yend = ward),
               linewidth = 1.5) +
  geom_point(size = 3) +
  geom_text(aes(label = paste0(round(avg_payment / 1000, 1), "K")),
            hjust = -0.5, size = 3, fontface = "bold", color = "black") +
  scale_color_viridis_c(option = "plasma", guide = "none") +
  scale_x_continuous(labels = label_number(suffix = "K", scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "All Wards by Average Payment",
    subtitle = "Period: 2021-2025",
    x = "Average Payment (Thousands Le)",
    y = NULL,
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank())
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_all_avg_payment.png", p_ward_avg, width = 10, height = 20, dpi = 300)


# Top 5 Wards by Business License Revenue with multiple metrics
ward_bl_summary <- df_clean %>%
  filter(!is.na(ward) & ward != "" & type == "business") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_revenue)) %>%
  slice_head(n = 5)
# Create combined chart with facets
ward_bl_long <- ward_bl_summary %>%
  mutate(ward = fct_reorder(ward, total_revenue)) %>%
  pivot_longer(cols = c(total_revenue, payment_count, avg_payment),
               names_to = "metric",
               values_to = "value") %>%
  mutate(metric = factor(metric, 
                         levels = c("total_revenue", "payment_count", "avg_payment"),
                         labels = c("Total Revenue (Millions Le)", 
                                    "Number of Payments", 
                                    "Average Payment (Thousands Le)")),
         value_scaled = case_when(
           metric == "Total Revenue (Millions Le)" ~ value / 1e6,
           metric == "Average Payment (Thousands Le)" ~ value / 1000,
           TRUE ~ value
         ))
p_ward_bl_top5 <- ggplot(ward_bl_long, aes(x = ward, y = value_scaled, fill = ward)) +
  geom_col(alpha = 0.8, show.legend = FALSE) +
  geom_text(aes(label = round(value_scaled, 2)),
            vjust = 1.5, size = 3.5, fontface = "bold", color = "white") +
  scale_fill_brewer(palette = "Dark2") +
  facet_wrap(~metric, scales = "free_y", ncol = 1) +
  labs(
    title = "Top 5 Wards by Business License Revenue - Comprehensive View",
    subtitle = "Total Revenue, Payment Count, and Average Payment (2021-2025)",
    x = NULL,
    y = NULL,
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(strip.text = element_text(face = "bold", size = 11))
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_top5_business_license_comprehensive.png", 
       p_ward_bl_top5, width = 12, height = 10, dpi = 300)

################################################################################
# PART 6: BANK ANALYSIS
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

# Créer une palette de couleurs cohérente
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
    subtitle = "Total collection per banking partner (2021-2025)",
    x = "Total Revenue (Millions Le)",
    y = NULL
  ) +
  theme_fcc()

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

# Combiner les deux graphiques
p16_combined <- p16_bar + p16_donut + 
  plot_annotation(
    caption = "Source: FCC Property Tax Database",
    theme = theme(plot.caption = element_text(hjust = 1, size = 9))
  )
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/16_banks_revenue_combined.png", 
       p16_combined, width = 16, height = 8, dpi = 300)

# 6.2 Bank Monthly Evolution - Payment count excluding Other and FCC
bank_monthly_count <- df_clean %>%
  filter(!bank %in% c("Other", "FCC")) %>%
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
    subtitle = "Number of payments over time (2021-2025)",
    x = NULL,
    y = "Number of Payments",
    caption = "Source: FCC Property Tax Database | Excluding Other and FCC"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/17_banks_monthly_payment_count.png", p17, width = 14, height = 7, dpi = 300)

# 6.2 Bank Monthly Evolution - Cumulative revenue excluding Other and FCC
bank_monthly_cumulative <- df_clean %>%
  filter(!bank %in% c("Other", "FCC")) %>%
  group_by(bank, year_month) %>%
  summarise(monthly_revenue = sum(payment, na.rm = TRUE), .groups = "drop") %>%
  group_by(bank) %>%
  arrange(year_month) %>%
  mutate(cumulative_revenue = cumsum(monthly_revenue)) %>%
  ungroup()

p17 <- ggplot(bank_monthly_cumulative, aes(x = year_month, y = cumulative_revenue / 1e6, color = bank)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  geom_point(size = 2) +
  scale_color_brewer(palette = "Dark2", name = "Bank") +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
  scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Cumulative Revenue Evolution by Bank",
    subtitle = "Total accumulated revenue over time (2021-2025)",
    x = NULL,
    y = "Cumulative Revenue (Millions Le)",
    caption = "Source: FCC Property Tax Database | Excluding Other and FCC"
  ) +
  theme_fcc()
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/17_banks_cumulative_revenue.png", p17, width = 14, height = 7, dpi = 300)

################################################################################
# PART 7: CROSS-SECTIONAL ANALYSIS
################################################################################

cat("Creating bank preferences for top and bottom 5 wards by average payment...\n")
# Create ward summary first
ward_summary <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_revenue))

# Identify top 5 wards by average payment
top_5_avg_wards <- ward_summary %>% 
  arrange(desc(avg_payment)) %>% 
  slice_head(n = 5) %>% 
  pull(ward)
# Calculate payment distribution by bank for these wards
ward_bank_pref_top <- df_clean %>%
  filter(ward %in% top_5_avg_wards, !is.na(bank)) %>%
  group_by(ward, bank) %>%
  summarise(
    payment_count = n(),
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(ward) %>%
  mutate(percentage = payment_count / sum(payment_count) * 100) %>%
  ungroup()
p_bank_pref_top <- ggplot(ward_bank_pref_top, aes(x = ward, y = percentage, fill = bank)) +
  geom_col(alpha = 0.9, position = "stack") +
  geom_text(aes(label = ifelse(percentage > 5, paste0(round(percentage, 1), "%"), "")),
            position = position_stack(vjust = 0.5), size = 3.5, fontface = "bold", color = "white") +
  scale_fill_brewer(palette = "Dark2", name = "Bank") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Top 5 Wards by Average Payment",
    x = NULL,
    y = "Percentage of Payments"
  ) +
  theme_fcc() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
# Bottom 5
bottom_5_avg_wards <- ward_summary %>% 
  arrange(avg_payment) %>% 
  slice_head(n = 5) %>% 
  pull(ward)
ward_bank_pref_bottom <- df_clean %>%
  filter(ward %in% bottom_5_avg_wards, !is.na(bank)) %>%
  group_by(ward, bank) %>%
  summarise(
    payment_count = n(),
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(ward) %>%
  mutate(percentage = payment_count / sum(payment_count) * 100) %>%
  ungroup()
p_bank_pref_bottom <- ggplot(ward_bank_pref_bottom, aes(x = ward, y = percentage, fill = bank)) +
  geom_col(alpha = 0.9, position = "stack") +
  geom_text(aes(label = ifelse(percentage > 5, paste0(round(percentage, 1), "%"), "")),
            position = position_stack(vjust = 0.5), size = 3.5, fontface = "bold", color = "white") +
  scale_fill_brewer(palette = "Dark2", name = "Bank") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Bottom 5 Wards by Average Payment",
    x = NULL,
    y = "Percentage of Payments"
  ) +
  theme_fcc() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
# Combine both graphs
p_bank_pref_combined <- p_bank_pref_top + p_bank_pref_bottom + 
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Bank Preferences by Ward Average Payment Level",
    subtitle = "Distribution of payments by bank (2021-2025)",
    caption = "Source: FCC Property Tax Database",
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
                  plot.subtitle = element_text(size = 12, hjust = 0.5),
                  plot.caption = element_text(hjust = 1, size = 9))
  )
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_top_bottom5_bank_preferences.png", 
       p_bank_pref_combined, width = 16, height = 8, dpi = 300)


cat("Creating bank preferences for top and bottom 5 wards by average payment...\n")
# Create ward summary first
ward_summary <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    avg_payment = mean(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_revenue))

# Identify top 5 wards by average payment
top_5_avg_wards <- ward_summary %>% 
  arrange(desc(avg_payment)) %>% 
  slice_head(n = 5) %>% 
  pull(ward)

# Calculate payment distribution by bank for top 5 wards (aggregated)
ward_bank_pref_top <- df_clean %>%
  filter(ward %in% top_5_avg_wards, !is.na(bank)) %>%
  group_by(bank) %>%
  summarise(
    payment_count = n(),
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(percentage = payment_count / sum(payment_count) * 100,
         category = "Top 5 Wards")

# Bottom 5
bottom_5_avg_wards <- ward_summary %>% 
  arrange(avg_payment) %>% 
  slice_head(n = 5) %>% 
  pull(ward)

ward_bank_pref_bottom <- df_clean %>%
  filter(ward %in% bottom_5_avg_wards, !is.na(bank)) %>%
  group_by(bank) %>%
  summarise(
    payment_count = n(),
    total_revenue = sum(payment, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(percentage = payment_count / sum(payment_count) * 100,
         category = "Bottom 5 Wards")

# Combine data
ward_bank_combined <- bind_rows(ward_bank_pref_top, ward_bank_pref_bottom)

# Create combined plot
p_bank_pref_combined <- ggplot(ward_bank_combined, aes(x = category, y = percentage, fill = bank)) +
  geom_col(alpha = 0.9, position = "stack") +
  geom_text(aes(label = paste0(round(percentage, 1), "%")),
            position = position_stack(vjust = 0.5), size = 3.5, fontface = "bold", color = "white") +
  scale_fill_brewer(palette = "Dark2", name = "Bank") +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Bank Preferences by Ward Average Payment Level",
    subtitle = "Distribution of payments by bank (2021-2025)",
    x = NULL,
    y = "Percentage of Payments",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc() +
  theme(axis.text.x = element_text(size = 11, face = "bold"))

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_top_bottom5_bank_preferences2.png", 
       p_bank_pref_combined, width = 12, height = 8, dpi = 300)

cat("Creating ward map with average payment...\n")
# Read gpkg file
wards_spatial <- st_read("D:/Dropbox/LoGRI/Sierra_Leone/data/1_Raw/revenue_reporting/Freetown/Ward/Western_Urban_Wards.gpkg")
# Calculate average payment per ward
ward_avg_payment <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    avg_payment = mean(payment, na.rm = TRUE),
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    .groups = "drop"
  )
# Join spatial data with payment data (converting Ward_No to character)
wards_map <- wards_spatial %>%
  mutate(Ward_No = as.character(Ward_No)) %>%
  left_join(ward_avg_payment, by = c("Ward_No" = "ward"))
# Disable s2 and calculate centroids for labels
sf_use_s2(FALSE)
wards_centroids <- st_centroid(wards_map, of_largest_polygon = TRUE)
# Create map
p_ward_map <- ggplot(wards_map) +
  geom_sf(aes(fill = avg_payment / 1000), color = "white", linewidth = 0.3) +
  geom_sf_text(data = wards_centroids %>% filter(!Ward_No %in% c("417", "431", "418", "415", "401")), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold") +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "417"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.005, nudge_y = -0.002) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "431"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = -0.005) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "418"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.002) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "415"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.001) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "401"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.002) +
  scale_fill_viridis_c(option = "plasma", 
                       name = "Average Payment\n(Thousands Le)",
                       na.value = "grey90",
                       labels = label_number(suffix = "K", scale = 1)) +
  labs(
    title = "Average Payment by Ward",
    subtitle = "Geographic distribution of average payments (2021-2025)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5),
    plot.caption = element_text(hjust = 1, size = 9),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank()
  )
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_map_avg_payment.png", 
       p_ward_map, width = 12, height = 10, dpi = 300)


cat("Creating ward map with total revenue...\n")
# Read gpkg file
wards_spatial <- st_read("D:/Dropbox/LoGRI/Sierra_Leone/data/1_Raw/revenue_reporting/Freetown/Ward/Western_Urban_Wards.gpkg")
# Calculate average payment per ward
ward_avg_payment <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    avg_payment = mean(payment, na.rm = TRUE),
    total_revenue = sum(payment, na.rm = TRUE),
    payment_count = n(),
    .groups = "drop"
  )
# Join spatial data with payment data (converting Ward_No to character)
wards_map <- wards_spatial %>%
  mutate(Ward_No = as.character(Ward_No)) %>%
  left_join(ward_avg_payment, by = c("Ward_No" = "ward"))
# Disable s2 and calculate centroids for labels
sf_use_s2(FALSE)
wards_centroids <- st_centroid(wards_map, of_largest_polygon = TRUE)

# Create map
p_ward_map_revenue <- ggplot(wards_map) +
  geom_sf(aes(fill = total_revenue / 1e6), color = "white", linewidth = 0.3) +
  geom_sf_text(data = wards_centroids %>% filter(!Ward_No %in% c("417", "431", "418", "415", "401")), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold") +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "417"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.005, nudge_y = -0.002) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "431"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = -0.005) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "418"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.002) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "415"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.001) +
  geom_sf_text(data = wards_centroids %>% filter(Ward_No == "401"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.002) +
  scale_fill_viridis_c(option = "plasma", 
                       name = "Total Revenue\n(Millions Le)",
                       na.value = "grey90",
                       labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Total Revenue by Ward",
    subtitle = "Geographic distribution of total revenue (2021-2025)",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5),
    plot.caption = element_text(hjust = 1, size = 9),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank()
  )
ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_map_total_revenue.png", 
       p_ward_map_revenue, width = 12, height = 10, dpi = 300)


cat("Creating ward map with outstanding revenue...\n")

# Load the default payers data
df_default <- read_dta("D:/Dropbox/LoGRI/Sierra_Leone/data/3_Final/revenue_reporting/Freetown/FCC_default_analysis.dta")

# Calculate total outstanding revenue per ward
ward_outstanding <- df_default %>%
  filter(!is.na(Ward) & Ward != "") %>%
  group_by(Ward) %>%
  summarise(
    total_outstanding = sum(OutstandingLe, na.rm = TRUE),
    count_defaulters = n(),
    avg_outstanding = mean(OutstandingLe, na.rm = TRUE),
    .groups = "drop"
  )

# Join spatial data with outstanding data (converting Ward_No to character)
wards_map_outstanding <- wards_spatial %>%
  mutate(Ward_No = as.character(Ward_No)) %>%
  left_join(ward_outstanding, by = c("Ward_No" = "Ward"))

# Disable s2 and calculate centroids for labels
sf_use_s2(FALSE)
wards_centroids_outstanding <- st_centroid(wards_map_outstanding, of_largest_polygon = TRUE)

# Create map
p_ward_map_outstanding <- ggplot(wards_map_outstanding) +
  geom_sf(aes(fill = total_outstanding / 1e6), color = "white", linewidth = 0.3) +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(!Ward_No %in% c("417", "431", "418", "415", "401")), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold") +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(Ward_No == "417"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.005, nudge_y = -0.002) +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(Ward_No == "431"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = -0.005) +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(Ward_No == "418"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_x = 0.002) +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(Ward_No == "415"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.001) +
  geom_sf_text(data = wards_centroids_outstanding %>% filter(Ward_No == "401"), 
               aes(label = Ward_No), size = 2, color = "white", fontface = "bold", 
               nudge_y = -0.002) +
  scale_fill_viridis_c(option = "plasma", 
                       name = "Outstanding Revenue\n(Millions Le)",
                       na.value = "grey90",
                       labels = label_number(suffix = "M", scale = 1)) +
  labs(
    title = "Outstanding Revenue by Ward",
    subtitle = "Geographic distribution of uncollected tax revenue (Default Payers)",
    caption = "Source: FCC Default Payers Database"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5),
    plot.caption = element_text(hjust = 1, size = 9),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank()
  )

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_map_outstanding_revenue.png", 
       p_ward_map_outstanding, width = 12, height = 10, dpi = 300)


cat("Creating ward ranking: Outstanding vs Collected Revenue...\n")

# Load the default payers data if not already loaded
df_default <- read_dta("D:/Dropbox/LoGRI/Sierra_Leone/data/3_Final/revenue_reporting/Freetown/FCC_default_analysis.dta")

# Calculate total collected revenue per ward (from main database)
ward_collected <- df_clean %>%
  filter(!is.na(ward) & ward != "") %>%
  group_by(ward) %>%
  summarise(
    total_collected = sum(payment, na.rm = TRUE),
    payment_count = n(),
    .groups = "drop"
  )

# Calculate total outstanding revenue per ward (from default database)
ward_outstanding <- df_default %>%
  filter(!is.na(Ward) & Ward != "") %>%
  group_by(Ward) %>%
  summarise(
    total_outstanding = sum(OutstandingLe, na.rm = TRUE),
    count_defaulters = n(),
    .groups = "drop"
  )

# Combine both datasets
ward_combined <- ward_collected %>%
  left_join(ward_outstanding, by = c("ward" = "Ward")) %>%
  mutate(
    total_outstanding = replace_na(total_outstanding, 0),
    count_defaulters = replace_na(count_defaulters, 0),
    total_potential = total_collected + total_outstanding,
    pct_outstanding = (total_outstanding / total_potential) * 100,
    collection_rate = (total_collected / total_potential) * 100
  ) %>%
  arrange(desc(pct_outstanding))

# Print summary
cat("\n=== WARD RANKING: OUTSTANDING vs COLLECTED REVENUE ===\n")
print(ward_combined %>% select(ward, total_collected, total_outstanding, pct_outstanding, collection_rate))

# Save to CSV
write.csv(ward_combined, 
          "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_collection_performance.csv",
          row.names = FALSE)

# Visualisation - Top 15 and Bottom 15 by % outstanding
top_bottom_wards <- bind_rows(
  ward_combined %>% slice_head(n = 15) %>% mutate(category = "Top 15 (Highest % Outstanding)"),
  ward_combined %>% slice_tail(n = 15) %>% mutate(category = "Bottom 15 (Lowest % Outstanding)")
)

p_ranking <- top_bottom_wards %>%
  mutate(ward = fct_reorder(ward, pct_outstanding),
         category = factor(category, levels = c("Top 15 (Highest % Outstanding)", "Bottom 15 (Lowest % Outstanding)"))) %>%
  ggplot(aes(x = pct_outstanding, y = ward, color = category)) +
  geom_segment(aes(x = 0, xend = pct_outstanding, y = ward, yend = ward), linewidth = 1.5) +
  geom_point(size = 4) +
  geom_text(aes(label = paste0(round(pct_outstanding, 1), "%")),
            hjust = -0.3, size = 3, fontface = "bold", color = "black") +
  scale_color_manual(values = c("Top 15 (Highest % Outstanding)" = "#8B0000", 
                                "Bottom 15 (Lowest % Outstanding)" = "#006400")) +
  scale_x_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Ward Collection Performance: Outstanding vs Collected Revenue",
    subtitle = "% of outstanding revenue relative to total potential revenue",
    x = "Outstanding Revenue (%)",
    y = NULL,
    color = NULL,
    caption = "Source: FCC Property Tax Database & Default Payers Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank(),
        legend.position = "top")

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_collection_performance_ranking.png", 
       p_ranking, width = 12, height = 12, dpi = 300)


# Visualisation - Top 15 and Bottom 15 by % outstanding (based on payment count)
# Recalculer avec le pourcentage basé sur le nombre de paiements
ward_combined_count <- ward_combined %>%
  mutate(
    total_potential_count = payment_count + count_defaulters,
    pct_outstanding_count = (count_defaulters / total_potential_count) * 100,
    collection_rate_count = (payment_count / total_potential_count) * 100
  )

top_bottom_wards_count <- bind_rows(
  ward_combined_count %>% arrange(desc(pct_outstanding_count)) %>% slice_head(n = 15) %>% mutate(category = "Top 15 (Highest % Outstanding)"),
  ward_combined_count %>% arrange(desc(pct_outstanding_count)) %>% slice_tail(n = 15) %>% mutate(category = "Bottom 15 (Lowest % Outstanding)")
)

p_ranking_count <- top_bottom_wards_count %>%
  mutate(ward = fct_reorder(ward, pct_outstanding_count),
         category = factor(category, levels = c("Top 15 (Highest % Outstanding)", "Bottom 15 (Lowest % Outstanding)"))) %>%
  ggplot(aes(x = pct_outstanding_count, y = ward, color = category)) +
  geom_segment(aes(x = 0, xend = pct_outstanding_count, y = ward, yend = ward), linewidth = 1.5) +
  geom_point(size = 4) +
  geom_text(aes(label = paste0(round(pct_outstanding_count, 1), "%")),
            hjust = -0.3, size = 3, fontface = "bold", color = "black") +
  scale_color_manual(values = c("Top 15 (Highest % Outstanding)" = "#8B0000", 
                                "Bottom 15 (Lowest % Outstanding)" = "#006400")) +
  scale_x_continuous(labels = label_percent(scale = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Ward Collection Performance: Outstanding vs Collected (Payment Count)",
    subtitle = "% of defaulters relative to total potential taxpayers",
    x = "Outstanding Payments (%)",
    y = NULL,
    color = NULL,
    caption = "Source: FCC Property Tax Database & Default Payers Database"
  ) +
  theme_fcc() +
  theme(panel.grid.major.y = element_blank(),
        legend.position = "top")

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/ward_collection_performance_ranking_count.png", 
       p_ranking_count, width = 12, height = 12, dpi = 300)

################################################################################
# PART 8: PAYMENT DISTRIBUTION ANALYSIS
################################################################################

cat("Creating payment distribution visualizations...\n")

# 8.1 Payment Distribution - Histogram with log scale
p21 <- df_clean %>%
  filter(payment > 0, payment < 50000) %>%
  ggplot(aes(x = payment)) +
  geom_histogram(aes(y = after_stat(density)), bins = 100, 
                 fill = fcc_colors["primary"], alpha = 0.7, color = "white") +
  geom_density(color = fcc_colors["secondary"], linewidth = 1.5) +
  scale_x_log10(labels = label_comma()) +
  labs(
    title = "Payment Amount Distribution",
    subtitle = "Histogram with density overlay (0 < payment < 50,000 Le, log scale)",
    x = "Payment Amount (Le, log scale)",
    y = "Density",
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/21_payment_distribution.png", p21, width = 12, height = 7, dpi = 300)

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
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/22_payment_categories_time.png", p22, width = 14, height = 7, dpi = 300)

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
    caption = "Source: FCC Property Tax Database | Note: 2025 data through December 12"
  ) +
  theme_fcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/27_cumulative_revenue.png", p27, width = 14, height = 7, dpi = 300)


# 9.4. Test Chi-carré - Payment catégorisé vs Bank
df_chi <- df_clean %>%
  filter(!is.na(bank), !is.na(payment)) %>%
  mutate(payment_quartile = cut(payment, 
                                breaks = quantile(payment, probs = 0:4/4),
                                labels = c("Q1 (Low)", "Q2", "Q3", "Q4 (High)"),
                                include.lowest = TRUE))

chi_test <- chisq.test(table(df_chi$payment_quartile, df_chi$bank))
print(chi_test)
# Tableau croisé : % par quartile de payment
cross_tab <- df_chi %>%
  group_by(payment_quartile, bank) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(payment_quartile) %>%
  mutate(pct = n / sum(n) * 100) %>%
  select(payment_quartile, bank, pct) %>%
  pivot_wider(names_from = bank, values_from = pct, values_fill = 0)
print(cross_tab)

#Visualisation du tableau croisé
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
    caption = "Source: FCC Property Tax Database"
  ) +
  theme_fcc()

ggsave("D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/bank_by_payment_quartile.png", 
       p3, width = 12, height = 7, dpi = 300)


# 9.5. Créer une régression linéaire simple (Bank encodé en numérique)
df_reg <- df_clean %>%
  filter(!is.na(bank), !is.na(payment)) %>%
  mutate(bank_factor = factor(bank, levels = c("Rokel Bank", "Access Bank", "EcoBank", 
                                               "FCC", "Other", "SLCB", "Zenith Bank")))

# Régression : Payment expliqué par Bank (avec Rokel Bank comme référence)
model <- lm(payment ~ bank_factor, data = df_reg)
summary(model)
stargazer(model, 
          type = "text",
          title = "Regression: Payment Amount by Bank Choice",
          dep.var.labels = "Payment Amount (Le)",
          covariate.labels = c("Access Bank", "EcoBank", "FCC", "Other", 
                               "SLCB", "Zenith Bank", "Constant (Rokel Bank)"),
          notes = "Reference category: Rokel Bank",
          notes.align = "l",
          out = "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/regression_table.txt")

# Sauvegarder en HTML
stargazer(model, 
          type = "html",
          title = "Regression: Payment Amount by Bank Choice",
          dep.var.labels = "Payment Amount (Le)",
          covariate.labels = c("Access Bank", "EcoBank", "FCC", "Other", 
                               "SLCB", "Zenith Bank", "Constant (Rokel Bank)"),
          notes = "Reference category: Rokel Bank. *** p<0.01, ** p<0.05, * p<0.1",
          notes.align = "l",
          out = "D:/Dropbox/LoGRI/Sierra_Leone/output/revenue_reporting/Freetown/regression_table.html")


################################################################################
# SAVE WORKSPACE (Optional)
################################################################################

# Save the workspace for future reference or additional analysis
save.image("plots/fcc_analysis_workspace.RData")
cat("Workspace saved: plots/fcc_analysis_workspace.RData\n")

cat("\n✓ All tasks completed successfully!\n")
cat("================================================================================\n")

################################################################################
# END OF SCRIPT
################################################################################

