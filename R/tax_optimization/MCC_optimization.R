# ==============================================================================
# PROPERTY TAX REVENUE MODELING - MAKENI
# ==============================================================================
# Objective: Model revenue increase to reach 500,000 Leones
# Date: 2024-12-18
# ==============================================================================

# Load required packages
library(tidyverse)
library(scales)
library(knitr)

# ==============================================================================
# PATH CONFIGURATION
# ==============================================================================

# Data file path - USE FORWARD SLASHES (/) even on Windows
input_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/data/1_Raw/tax_optimization/Makeni/valuation_and_rate_book_20251218.csv"

# Output path for graphics - USE FORWARD SLASHES (/) even on Windows
output_path <- "D:/LoGRI Dropbox/Robin Benabid Jegaden/LoGRI/Sierra_Leone/output/tax_optimization/Makeni"

# Create output folder if it doesn't exist
if (!dir.exists(output_path)) {
  dir.create(output_path, recursive = TRUE)
}

# ==============================================================================
# 1. DATA LOADING AND PREPARATION
# ==============================================================================

# Read CSV file
df <- read_csv(input_path, show_col_types = FALSE)

# Clean and convert numeric columns
df <- df %>%
  mutate(
    # Remove commas and convert to numeric
    assessed_annual_value = as.numeric(gsub(",", "", `Assessed Annual Value`)),
    property_tax = as.numeric(gsub(",", "", `Property Tax`))
  )

# ==============================================================================
# 2. CURRENT SITUATION ANALYSIS
# ==============================================================================

cat("\n=== CURRENT SITUATION ===\n")

# Current parameters
current_tax_rate <- 0.04  # 4%
current_minimum <- 50     # 50 Leones

# Calculate current revenue
current_revenue <- sum(df$property_tax, na.rm = TRUE)

cat(sprintf("Current total revenue: %s Leones\n", 
            format(current_revenue, big.mark = ",", scientific = FALSE)))

# Identify properties at minimum
df <- df %>%
  mutate(
    # Calculate theoretical tax without minimum
    theoretical_tax = assessed_annual_value * current_tax_rate,
    # Identify if property is at minimum
    is_at_minimum = property_tax == current_minimum
  )

# Statistics by category
n_at_minimum <- sum(df$is_at_minimum, na.rm = TRUE)
n_above_minimum <- sum(!df$is_at_minimum, na.rm = TRUE)

cat(sprintf("\nNumber of properties at minimum (50 L): %d (%.1f%%)\n", 
            n_at_minimum, 100 * n_at_minimum / nrow(df)))
cat(sprintf("Number of properties above minimum: %d (%.1f%%)\n", 
            n_above_minimum, 100 * n_above_minimum / nrow(df)))

# Revenue by category
revenue_from_minimum <- sum(df$property_tax[df$is_at_minimum], na.rm = TRUE)
revenue_from_above <- sum(df$property_tax[!df$is_at_minimum], na.rm = TRUE)

cat(sprintf("\nRevenue from properties at minimum: %s L (%.1f%%)\n", 
            format(revenue_from_minimum, big.mark = ",", scientific = FALSE),
            100 * revenue_from_minimum / current_revenue))
cat(sprintf("Revenue from properties above minimum: %s L (%.1f%%)\n", 
            format(revenue_from_above, big.mark = ",", scientific = FALSE),
            100 * revenue_from_above / current_revenue))

# ==============================================================================
# 3. REVENUE CALCULATION FUNCTION
# ==============================================================================

calculate_revenue <- function(data, tax_rate, minimum_amount) {
  # Calculate property tax with new rate and minimum
  data %>%
    mutate(
      new_tax = pmax(assessed_annual_value * tax_rate, minimum_amount)
    ) %>%
    summarise(total_revenue = sum(new_tax, na.rm = TRUE)) %>%
    pull(total_revenue)
}

# ==============================================================================
# 4. SCENARIO MODELING
# ==============================================================================

cat("\n\n=== SCENARIO MODELING ===\n")
cat(sprintf("Revenue target: 500,000 Leones\n"))
cat(sprintf("Required increase: %s Leones (%.1f%%)\n\n",
            format(500000 - current_revenue, big.mark = ",", scientific = FALSE),
            100 * (500000 - current_revenue) / current_revenue))

# --- Scenario 1: Tax rate increase only ---
cat("--- SCENARIO 1: Tax rate increase only (minimum = 50 L) ---\n")

# Search for required rate
tax_rates <- seq(0.04, 0.10, by = 0.001)
revenues_scenario1 <- sapply(tax_rates, function(rate) {
  calculate_revenue(df, rate, current_minimum)
})

# Find exact rate to reach 500,000
target_rate_idx <- which(revenues_scenario1 >= 500000)[1]
target_rate <- tax_rates[target_rate_idx]
target_revenue <- revenues_scenario1[target_rate_idx]

cat(sprintf("Required new rate: %.2f%% (currently %.2f%%)\n", 
            target_rate * 100, current_tax_rate * 100))
cat(sprintf("Rate increase: +%.2f percentage points\n", 
            (target_rate - current_tax_rate) * 100))
cat(sprintf("Projected revenue: %s Leones\n\n", 
            format(target_revenue, big.mark = ",", scientific = FALSE)))

# --- Scenario 2: Minimum increase only ---
cat("--- SCENARIO 2: Minimum increase only (rate = 4%) ---\n")

# Search for required minimum
minimums <- seq(50, 2000, by = 10)
revenues_scenario2 <- sapply(minimums, function(min_amt) {
  calculate_revenue(df, current_tax_rate, min_amt)
})

# Find exact minimum to reach 500,000
if (any(revenues_scenario2 >= 500000)) {
  target_min_idx <- which(revenues_scenario2 >= 500000)[1]
  target_minimum <- minimums[target_min_idx]
  target_revenue2 <- revenues_scenario2[target_min_idx]
  
  cat(sprintf("Required new minimum: %s Leones (currently %s L)\n", 
              format(target_minimum, big.mark = ",", scientific = FALSE),
              format(current_minimum, big.mark = ",", scientific = FALSE)))
  cat(sprintf("Minimum increase: +%s Leones\n", 
              format(target_minimum - current_minimum, big.mark = ",", scientific = FALSE)))
  cat(sprintf("Projected revenue: %s Leones\n\n", 
              format(target_revenue2, big.mark = ",", scientific = FALSE)))
  scenario2_possible <- TRUE
} else {
  cat("IMPOSSIBLE to reach 500,000 L by increasing minimum only!\n")
  cat(sprintf("Maximum possible revenue (minimum = 2000 L): %s Leones\n\n", 
              format(max(revenues_scenario2), big.mark = ",", scientific = FALSE)))
  scenario2_possible <- FALSE
  target_minimum <- NA
  target_revenue2 <- NA
}

# --- Scenario 3: Mixed approach (moderate increase of both) ---
cat("--- SCENARIO 3: Mixed approach ---\n")

# Explore different combinations
mixed_scenarios <- expand.grid(
  tax_rate = seq(0.04, 0.08, by = 0.005),
  minimum = seq(50, 300, by = 25)
)

mixed_scenarios$revenue <- mapply(function(rate, min_amt) {
  calculate_revenue(df, rate, min_amt)
}, mixed_scenarios$tax_rate, mixed_scenarios$minimum)

# Find combinations that reach the target
viable_mixed <- mixed_scenarios %>%
  filter(revenue >= 500000) %>%
  arrange(revenue)

# Display top 5 mixed options
cat("Top 5 balanced combinations:\n\n")
top_mixed <- viable_mixed %>%
  mutate(
    rate_increase = (tax_rate - current_tax_rate) * 100,
    min_increase = minimum - current_minimum
  ) %>%
  head(5)

for(i in 1:nrow(top_mixed)) {
  cat(sprintf("  Option %d:\n", i))
  cat(sprintf("    - Rate: %.2f%% (+%.2f points)\n", 
              top_mixed$tax_rate[i] * 100, top_mixed$rate_increase[i]))
  cat(sprintf("    - Minimum: %s L (+%s L)\n", 
              format(top_mixed$minimum[i], big.mark = ",", scientific = FALSE),
              format(top_mixed$min_increase[i], big.mark = ",", scientific = FALSE)))
  cat(sprintf("    - Revenue: %s L\n\n", 
              format(round(top_mixed$revenue[i]), big.mark = ",", scientific = FALSE)))
}

# --- Scenario 4: Balanced percentage increases ---
cat("--- SCENARIO 4: Balanced percentage increases ---\n")
cat("Finding combinations with similar % increases for both rate and minimum...\n\n")

# Create a finer grid for this analysis - FOCUSED RANGE
balanced_scenarios <- expand.grid(
  tax_rate = seq(0.04, 0.08, by = 0.001),
  minimum = seq(50, 200, by = 2)
)

balanced_scenarios <- balanced_scenarios %>%
  mutate(
    # Calculate percentage increases
    rate_pct_increase = 100 * (tax_rate - current_tax_rate) / current_tax_rate,
    min_pct_increase = 100 * (minimum - current_minimum) / current_minimum,
    # Calculate difference between the two percentage increases
    pct_difference = abs(rate_pct_increase - min_pct_increase),
    # Calculate revenue
    revenue = mapply(function(r, m) calculate_revenue(df, r, m), tax_rate, minimum)
  ) %>%
  # Keep only combinations that reach the target
  filter(revenue >= 500000)

# Find the most balanced options (smallest difference in percentage increases)
most_balanced <- balanced_scenarios %>%
  arrange(pct_difference, revenue) %>%
  head(5)

cat("Top 5 most balanced options (equal % increases):\n\n")
for(i in 1:nrow(most_balanced)) {
  cat(sprintf("  Option %d:\n", i))
  cat(sprintf("    - Rate: %.2f%% → %.2f%% (+%.1f%% increase)\n", 
              current_tax_rate * 100, 
              most_balanced$tax_rate[i] * 100,
              most_balanced$rate_pct_increase[i]))
  cat(sprintf("    - Minimum: %s L → %s L (+%.1f%% increase)\n", 
              format(current_minimum, big.mark = ","),
              format(most_balanced$minimum[i], big.mark = ","),
              most_balanced$min_pct_increase[i]))
  cat(sprintf("    - Difference in increases: %.2f percentage points\n",
              most_balanced$pct_difference[i]))
  cat(sprintf("    - Revenue: %s L\n\n", 
              format(round(most_balanced$revenue[i]), big.mark = ",", scientific = FALSE)))
}

# ==============================================================================
# 5. SCENARIO COMPARISON TABLE
# ==============================================================================

cat("\n=== SCENARIO COMPARISON TABLE ===\n\n")

if (scenario2_possible) {
  comparison_table <- tibble(
    Scenario = c("Current", 
                 "Scenario 1: Rate only", 
                 "Scenario 2: Minimum only",
                 "Scenario 3: Mixed (Option 1)",
                 "Scenario 4: Balanced increases"),
    `Rate (%)` = c(current_tax_rate * 100,
                   target_rate * 100,
                   current_tax_rate * 100,
                   top_mixed$tax_rate[1] * 100,
                   most_balanced$tax_rate[1] * 100),
    `Minimum (L)` = c(current_minimum,
                      current_minimum,
                      target_minimum,
                      top_mixed$minimum[1],
                      most_balanced$minimum[1]),
    `Total Revenue (L)` = c(current_revenue,
                            target_revenue,
                            target_revenue2,
                            top_mixed$revenue[1],
                            most_balanced$revenue[1]),
    `Increase (%)` = c(0,
                       100 * (target_revenue - current_revenue) / current_revenue,
                       100 * (target_revenue2 - current_revenue) / current_revenue,
                       100 * (top_mixed$revenue[1] - current_revenue) / current_revenue,
                       100 * (most_balanced$revenue[1] - current_revenue) / current_revenue)
  )
} else {
  comparison_table <- tibble(
    Scenario = c("Current", 
                 "Scenario 1: Rate only", 
                 "Scenario 3: Mixed (Option 1)",
                 "Scenario 4: Balanced increases"),
    `Rate (%)` = c(current_tax_rate * 100,
                   target_rate * 100,
                   top_mixed$tax_rate[1] * 100,
                   most_balanced$tax_rate[1] * 100),
    `Minimum (L)` = c(current_minimum,
                      current_minimum,
                      top_mixed$minimum[1],
                      most_balanced$minimum[1]),
    `Total Revenue (L)` = c(current_revenue,
                            target_revenue,
                            top_mixed$revenue[1],
                            most_balanced$revenue[1]),
    `Increase (%)` = c(0,
                       100 * (target_revenue - current_revenue) / current_revenue,
                       100 * (top_mixed$revenue[1] - current_revenue) / current_revenue,
                       100 * (most_balanced$revenue[1] - current_revenue) / current_revenue)
  )
}

print(kable(comparison_table, format = "simple", digits = 2))

# ==============================================================================
# 6. SCENARIO VISUALIZATION
# ==============================================================================

cat("\n\n=== Generating graphics ===\n")

# Graph 1: Revenue sensitivity to tax rate
p1 <- ggplot(data.frame(tax_rate = tax_rates, revenue = revenues_scenario1),
             aes(x = tax_rate * 100, y = revenue)) +
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_hline(yintercept = 500000, linetype = "dashed", color = "red", linewidth = 1) +
  geom_vline(xintercept = target_rate * 100, linetype = "dashed", 
             color = "darkgreen", linewidth = 1) +
  annotate("text", x = target_rate * 100, y = 450000, 
           label = sprintf("Required rate: %.2f%%", target_rate * 100),
           hjust = -0.1, color = "darkgreen") +
  annotate("text", x = 5, y = 500000, 
           label = "Target: 500,000 L", vjust = -0.5, color = "red") +
  labs(title = "Scenario 1: Impact of tax rate on revenue",
       subtitle = sprintf("Minimum fixed at %s Leones", current_minimum),
       x = "Tax rate (%)",
       y = "Total revenue (Leones)") +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11))

ggsave(file.path(output_path, "scenario1_tax_rate.png"), p1, width = 10, height = 6, dpi = 300)

# Graph 2: Revenue sensitivity to minimum
p2 <- ggplot(data.frame(minimum = minimums, revenue = revenues_scenario2),
             aes(x = minimum, y = revenue)) +
  geom_line(color = "coral", linewidth = 1.2) +
  geom_hline(yintercept = 500000, linetype = "dashed", color = "red", linewidth = 1)

if (scenario2_possible) {
  p2 <- p2 +
    geom_vline(xintercept = target_minimum, linetype = "dashed", 
               color = "darkgreen", linewidth = 1) +
    annotate("text", x = target_minimum, y = 450000, 
             label = sprintf("Required minimum: %s L", target_minimum),
             hjust = -0.1, color = "darkgreen")
} else {
  p2 <- p2 +
    annotate("text", x = 1000, y = 450000, 
             label = "Target unreachable\nwith this approach",
             hjust = 0.5, color = "red", fontface = "bold",
             size = 5)
}

p2 <- p2 +
  annotate("text", x = 100, y = 500000, 
           label = "Target: 500,000 L", vjust = -0.5, color = "red") +
  labs(title = "Scenario 2: Impact of minimum amount on revenue",
       subtitle = sprintf("Rate fixed at %.0f%%", current_tax_rate * 100),
       x = "Minimum amount (Leones)",
       y = "Total revenue (Leones)") +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(labels = comma) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11))

ggsave(file.path(output_path, "scenario2_minimum.png"), p2, width = 10, height = 6, dpi = 300)

# Graph 3: Heatmap of mixed combinations - MODIFIED
p3 <- ggplot(mixed_scenarios, aes(x = tax_rate * 100, y = minimum, fill = revenue)) +
  geom_tile() +
  scale_fill_gradient2(low = "lightblue", mid = "yellow", high = "darkred",
                       midpoint = 500000, labels = comma,
                       name = "Revenue (L)") +
  scale_x_continuous(breaks = seq(4, 8, by = 0.5)) +
  scale_y_continuous(breaks = seq(50, 300, by = 50)) +
  labs(title = "Scenario 3: Rate-minimum combinations",
       subtitle = "Revenue projections for different policy combinations",
       x = "Tax rate (%)",
       y = "Minimum amount (Leones)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11),
        legend.position = "right")

ggsave(file.path(output_path, "scenario3_heatmap.png"), p3, width = 10, height = 6, dpi = 300)

# Graph 4: Current tax distribution
p4 <- ggplot(df, aes(x = property_tax)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white", alpha = 0.8) +
  geom_vline(xintercept = current_minimum, linetype = "dashed", 
             color = "red", linewidth = 1) +
  annotate("text", x = current_minimum, y = Inf, 
           label = sprintf("Minimum: %s L\n(%d properties)", 
                           current_minimum, n_at_minimum),
           vjust = 1.5, hjust = -0.1, color = "red") +
  labs(title = "Current property tax distribution",
       subtitle = sprintf("%d properties in total", nrow(df)),
       x = "Property Tax (Leones)",
       y = "Number of properties") +
  scale_x_continuous(labels = comma) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11))

ggsave(file.path(output_path, "current_distribution.png"), p4, width = 10, height = 6, dpi = 300)

# Graph 5: Balanced percentage increases - SIMPLIFIED
# Add option labels
most_balanced <- most_balanced %>%
  mutate(option_label = paste0("Option ", 1:n()))

# Calculate axis ranges with some padding
x_range <- range(most_balanced$rate_pct_increase)
y_range <- range(most_balanced$min_pct_increase)
x_padding <- diff(x_range) * 0.3
y_padding <- diff(y_range) * 0.3

p5 <- ggplot(most_balanced, aes(x = rate_pct_increase, y = min_pct_increase)) +
  # Add the 45-degree line for equal increases (thinner line)
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", 
              color = "darkgreen", linewidth = 0.5, alpha = 0.5) +
  # Add points for each option
  geom_point(aes(color = revenue, size = revenue), alpha = 0.8) +
  # Add labels for each option
  geom_text(aes(label = option_label), hjust = -0.3, vjust = 0.5, 
            fontface = "bold", size = 4) +
  scale_color_gradient(low = "lightblue", high = "darkred",
                       labels = comma, name = "Revenue (L)") +
  scale_size_continuous(range = c(8, 12), guide = "none") +
  scale_x_continuous(limits = c(min(most_balanced$rate_pct_increase) - x_padding,
                                max(most_balanced$rate_pct_increase) + x_padding),
                     breaks = seq(0, 100, by = 10)) +
  scale_y_continuous(limits = c(min(most_balanced$min_pct_increase) - y_padding,
                                max(most_balanced$min_pct_increase) + y_padding),
                     breaks = seq(0, 200, by = 20)) +
  labs(title = "Scenario 4: Top 5 balanced percentage increases",
       subtitle = "Options with most similar % increases for both tax rate and minimum amount",
       x = "Tax rate % increase (from current 4%)",
       y = "Minimum amount % increase (from current 50 L)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11),
        legend.position = "right",
        panel.grid.minor = element_blank())

ggsave(file.path(output_path, "scenario4_balanced_increases.png"), p5, width = 12, height = 8, dpi = 300)

cat("Graphics saved in:", output_path, "\n")
cat("  - scenario1_tax_rate.png\n")
cat("  - scenario2_minimum.png\n")
cat("  - scenario3_heatmap.png\n")
cat("  - scenario4_current_distribution.png\n")
cat("  - scenario5_balanced_increases.png\n")

# ==============================================================================
# 7. RESULTS EXPORT
# ==============================================================================

# Save results in a CSV file
write_csv(comparison_table, file.path(output_path, "revenue_scenarios_summary.csv"))

# Save balanced scenarios details with more readable column names
balanced_export <- most_balanced %>%
  mutate(
    new_rate = tax_rate * 100,
    new_minimum = minimum,
    rate_pct_change = rate_pct_increase,
    minimum_pct_change = min_pct_increase,
    difference = pct_difference,
    projected_revenue = revenue
  ) %>%
  select(option_label, new_rate, rate_pct_change, new_minimum, 
         minimum_pct_change, difference, projected_revenue)

write_csv(balanced_export, file.path(output_path, "balanced_scenarios_details.csv"))

cat("\nResults exported to:", file.path(output_path, "revenue_scenarios_summary.csv"), "\n")
cat("Balanced scenarios details:", file.path(output_path, "balanced_scenarios_details.csv"), "\n")

cat("\n=== ANALYSIS COMPLETED ===\n")