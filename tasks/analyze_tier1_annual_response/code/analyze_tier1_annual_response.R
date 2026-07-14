# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/analyze_tier1_annual_response/code")
# analysis_start_year <- 2019L
# analysis_end_year <- 2025L

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

cli_args <- commandArgs(trailingOnly = TRUE)
if (interactive()) cli_args <- c(analysis_start_year, analysis_end_year)
if (length(cli_args) != 2) stop("Expected analysis_start_year and analysis_end_year.")
analysis_start_year <- as.integer(cli_args[1])
analysis_end_year <- as.integer(cli_args[2])

operating <- read_csv("../input/tier1_2018_2025_annual_operating_panel.csv", show_col_types = FALSE) |>
  arrange(ticker, fiscal_year) |>
  group_by(ticker) |>
  mutate(
    prior_fiscal_year = lag(fiscal_year),
    orders_units_growth = if_else(fiscal_year == prior_fiscal_year + 1L, orders_units / lag(orders_units) - 1, NA_real_),
    deliveries_units_growth = if_else(fiscal_year == prior_fiscal_year + 1L, deliveries_units / lag(deliveries_units) - 1, NA_real_),
    backlog_units_growth = if_else(fiscal_year == prior_fiscal_year + 1L, backlog_units / lag(backlog_units) - 1, NA_real_)
  ) |>
  ungroup()

land_lag <- read_csv("../input/expanded_builder_land_plot_data.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year) + 1L,
    lagged_omega = as.numeric(nonowned_controlled_share),
    selected_main_plot_eligible = selected_main_plot_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1)
  ) |>
  filter(selected_main_plot_eligible, !is.na(lagged_omega)) |>
  select(ticker, fiscal_year, lagged_omega, lagged_omega_source = selected_land_source)

if (land_lag |> count(ticker, fiscal_year) |> filter(n != 1) |> nrow() > 0) {
  stop("Lagged land-light inputs must be unique by ticker and fiscal year.")
}

response_panel <- operating |>
  left_join(land_lag, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  mutate(
    analysis_year = fiscal_year %in% analysis_start_year:analysis_end_year,
    annual_response_eligible = analysis_year & !is.na(lagged_omega) &
      !is.na(orders_units_growth) & !is.na(deliveries_units_growth) & !is.na(backlog_units_growth)
  ) |>
  arrange(ticker, fiscal_year)

plot_data <- response_panel |>
  filter(annual_response_eligible) |>
  mutate(fiscal_year = factor(fiscal_year, levels = analysis_start_year:analysis_end_year))

response_summary <- plot_data |>
  group_by(fiscal_year) |>
  summarise(
    firms = n(),
    order_growth_correlation = cor(lagged_omega, orders_units_growth),
    delivery_growth_correlation = cor(lagged_omega, deliveries_units_growth),
    backlog_growth_correlation = cor(lagged_omega, backlog_units_growth),
    .groups = "drop"
  )

order_plot <- ggplot(plot_data, aes(x = lagged_omega, y = orders_units_growth, label = ticker)) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey65") +
  geom_smooth(aes(label = NULL), method = "lm", formula = y ~ x, se = FALSE, linewidth = 0.7, color = "#b7342c") +
  geom_point(size = 1.7, color = "grey25") +
  geom_text(nudge_y = 0.025, size = 2.5, check_overlap = TRUE) +
  facet_wrap(~fiscal_year, ncol = 4) +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
  labs(
    title = "Annual Order Growth Versus Lagged Land-Light Share",
    subtitle = "Tier-1 public builders, fiscal years 2019-2025; red line is the within-year OLS fit",
    x = "Prior-year non-owned controlled share",
    y = "Net order unit growth",
    caption = "Only consecutive public firm-years with an audited operating count and usable prior-year land share are shown."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 8)),
    panel.grid.minor = element_blank()
  )

delivery_plot <- ggplot(plot_data, aes(x = lagged_omega, y = deliveries_units_growth, label = ticker)) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey65") +
  geom_smooth(aes(label = NULL), method = "lm", formula = y ~ x, se = FALSE, linewidth = 0.7, color = "#b7342c") +
  geom_point(size = 1.7, color = "grey25") +
  geom_text(nudge_y = 0.025, size = 2.5, check_overlap = TRUE) +
  facet_wrap(~fiscal_year, ncol = 4) +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
  labs(
    title = "Annual Delivery Growth Versus Lagged Land-Light Share",
    subtitle = "Tier-1 public builders, fiscal years 2019-2025; red line is the within-year OLS fit",
    x = "Prior-year non-owned controlled share",
    y = "Delivery unit growth",
    caption = "Deliveries are firm-reported closings, settlements, or equivalent completed home sales."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 8)),
    panel.grid.minor = element_blank()
  )

backlog_plot <- ggplot(plot_data, aes(x = lagged_omega, y = backlog_units_growth, label = ticker)) +
  geom_hline(yintercept = 0, linewidth = 0.3, color = "grey65") +
  geom_smooth(aes(label = NULL), method = "lm", formula = y ~ x, se = FALSE, linewidth = 0.7, color = "#b7342c") +
  geom_point(size = 1.7, color = "grey25") +
  geom_text(nudge_y = 0.04, size = 2.5, check_overlap = TRUE) +
  facet_wrap(~fiscal_year, ncol = 4) +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
  labs(
    title = "Annual Backlog Growth Versus Lagged Land-Light Share",
    subtitle = "Tier-1 public builders, fiscal years 2019-2025; red line is the within-year OLS fit",
    x = "Prior-year non-owned controlled share",
    y = "Year-end backlog unit growth",
    caption = "Backlog is the firm-reported count of sold homes under contract but not yet delivered at fiscal year end."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 8)),
    panel.grid.minor = element_blank()
  )

write_csv_if_changed(response_panel, "../output/tier1_annual_response_panel.csv")
write_csv_if_changed(response_summary, "../output/tier1_annual_response_summary.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, order_plot, width = 10, height = 7.2, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/tier1_order_growth_vs_lagged_omega.png")
temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, order_plot, width = 10, height = 7.2, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/tier1_order_growth_vs_lagged_omega.pdf")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, delivery_plot, width = 10, height = 7.2, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/tier1_delivery_growth_vs_lagged_omega.png")
temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, delivery_plot, width = 10, height = 7.2, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/tier1_delivery_growth_vs_lagged_omega.pdf")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, backlog_plot, width = 10, height = 7.2, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/tier1_backlog_growth_vs_lagged_omega.png")
temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, backlog_plot, width = 10, height = 7.2, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/tier1_backlog_growth_vs_lagged_omega.pdf")

cat("Wrote Tier-1 annual response outputs to ../output\n")
