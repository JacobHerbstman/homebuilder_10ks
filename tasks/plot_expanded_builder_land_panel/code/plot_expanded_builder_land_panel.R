# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/plot_expanded_builder_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

plot_data <- read_csv("../input/expanded_builder_land_plot_data.csv", show_col_types = FALSE, na = c("", "NA")) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    nonowned_physical_count = as.numeric(nonowned_physical_count),
    total_physical_count = as.numeric(total_physical_count),
    selected_main_plot_eligible = selected_main_plot_eligible %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    highlight_group = case_when(
      ticker %in% c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR") ~ "Six-firm pilot",
      ticker %in% c("DFH", "SDHC", "UHG", "LSEA") ~ "Recent public land-light",
      ticker %in% c("MDC", "TOL", "LGIH", "GRBK") ~ "Land-owner contrast",
      TRUE ~ "Other public builders"
    )
  ) |>
  filter(selected_main_plot_eligible, !is.na(nonowned_controlled_share)) |>
  arrange(ticker, fiscal_year)

if (nrow(plot_data) == 0) {
  stop("No usable observations for expanded builder land-share plot.")
}

summary_data <- plot_data |>
  group_by(fiscal_year) |>
  summarise(
    firm_years = n(),
    p25_share = quantile(nonowned_controlled_share, 0.25, na.rm = TRUE),
    median_share = median(nonowned_controlled_share, na.rm = TRUE),
    p75_share = quantile(nonowned_controlled_share, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

label_data <- plot_data |>
  filter(highlight_group != "Other public builders") |>
  group_by(ticker, company, highlight_group) |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(
    label_y = case_when(
      ticker == "NVR" ~ pmin(nonowned_controlled_share + 0.015, 1),
      ticker == "LEN" ~ pmax(nonowned_controlled_share - 0.015, 0),
      ticker == "PHM" ~ pmax(nonowned_controlled_share - 0.02, 0),
      ticker == "UHG" ~ pmin(nonowned_controlled_share + 0.015, 1),
      TRUE ~ nonowned_controlled_share
    )
  )

highlight_colors <- c(
  "Six-firm pilot" = "#1f4e79",
  "Recent public land-light" = "#c43c39",
  "Land-owner contrast" = "#2e7d32"
)

share_plot <- ggplot() +
  geom_line(
    data = plot_data |> filter(highlight_group == "Other public builders"),
    aes(x = fiscal_year, y = nonowned_controlled_share, group = ticker),
    color = "grey72",
    linewidth = 0.45,
    alpha = 0.55,
    na.rm = TRUE
  ) +
  geom_ribbon(
    data = summary_data,
    aes(x = fiscal_year, ymin = p25_share, ymax = p75_share),
    fill = "grey45",
    alpha = 0.14
  ) +
  geom_line(
    data = summary_data,
    aes(x = fiscal_year, y = median_share),
    color = "black",
    linewidth = 0.8
  ) +
  geom_line(
    data = plot_data |> filter(highlight_group != "Other public builders"),
    aes(x = fiscal_year, y = nonowned_controlled_share, group = ticker, color = highlight_group),
    linewidth = 0.85,
    alpha = 0.9,
    na.rm = TRUE
  ) +
  geom_point(
    data = plot_data |> filter(highlight_group != "Other public builders"),
    aes(x = fiscal_year, y = nonowned_controlled_share, color = highlight_group),
    size = 1.35,
    stroke = 0,
    alpha = 0.9,
    na.rm = TRUE
  ) +
  geom_text(
    data = label_data,
    aes(x = fiscal_year, y = label_y, label = ticker, color = highlight_group),
    hjust = 0,
    nudge_x = 0.2,
    size = 3,
    show.legend = FALSE
  ) +
  scale_color_manual(values = highlight_colors, name = NULL) +
  scale_x_continuous(
    breaks = seq(2004, 2025, by = 3),
    limits = c(2004, 2026.2),
    expand = c(0.01, 0)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(100 * x), "%"),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.1),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "Land-Light Share Across Public Homebuilders",
    subtitle = "Firm-specific 10-K extraction, fiscal years 2004-2025; black line is yearly median and band is IQR",
    x = NULL,
    y = "Non-owned / controlled share",
    caption = "Definitions are harmonized conservatively. Controlled buckets are not labeled optioned unless the filing uses optioned or equivalent language."
  ) +
  coord_cartesian(clip = "off") +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 9)),
    legend.position = "bottom",
    legend.justification = "left",
    axis.title.y = element_text(margin = margin(r = 8)),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(12, 46, 12, 12)
  )

write_csv_if_changed(plot_data, "../output/expanded_builder_nonowned_controlled_share_plot_data.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, share_plot, width = 9.3, height = 5.8, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/expanded_builder_nonowned_controlled_share_timeseries.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, share_plot, width = 9.3, height = 5.8, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/expanded_builder_nonowned_controlled_share_timeseries.pdf")

unbalanced_plot_data <- plot_data |>
  filter(fiscal_year >= 2006, fiscal_year <= 2025) |>
  arrange(ticker, fiscal_year)

unbalanced_summary_data <- unbalanced_plot_data |>
  group_by(fiscal_year) |>
  summarise(
    firm_years = n(),
    mean_share = mean(nonowned_controlled_share, na.rm = TRUE),
    .groups = "drop"
  )

unbalanced_mean_label_data <- unbalanced_summary_data |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  mutate(label_y = pmin(mean_share + 0.025, 1))

unbalanced_share_plot <- ggplot() +
  geom_line(
    data = unbalanced_plot_data,
    aes(x = fiscal_year, y = nonowned_controlled_share, group = ticker),
    color = "grey67",
    linewidth = 0.45,
    alpha = 0.6,
    na.rm = TRUE
  ) +
  geom_point(
    data = unbalanced_plot_data,
    aes(x = fiscal_year, y = nonowned_controlled_share),
    color = "grey67",
    size = 0.85,
    stroke = 0,
    alpha = 0.65,
    na.rm = TRUE
  ) +
  geom_line(
    data = unbalanced_summary_data,
    aes(x = fiscal_year, y = mean_share),
    color = "#1f4e79",
    linewidth = 1.35,
    lineend = "round"
  ) +
  geom_point(
    data = unbalanced_summary_data,
    aes(x = fiscal_year, y = mean_share),
    color = "#1f4e79",
    size = 1.7,
    stroke = 0
  ) +
  geom_text(
    data = unbalanced_mean_label_data,
    aes(x = fiscal_year, y = label_y, label = "Mean"),
    hjust = 0,
    nudge_x = 0.18,
    size = 3.1,
    color = "#1f4e79",
    fontface = "bold"
  ) +
  scale_x_continuous(
    breaks = seq(2006, 2025, by = 3),
    limits = c(2006, 2026.1),
    expand = c(0.01, 0)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(100 * x), "%"),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.1),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "Land-Light Share Across Public Homebuilders",
    subtitle = "Unbalanced fiscal years 2006-2025; blue line is the unweighted mean among firms observed each year",
    x = NULL,
    y = "Non-owned / controlled share",
    caption = paste0(
      "Grey lines are individual firms. The sample contains ",
      n_distinct(unbalanced_plot_data$ticker),
      " firms and ",
      nrow(unbalanced_plot_data),
      " firm-years; composition changes as firms enter and exit."
    )
  ) +
  coord_cartesian(clip = "off") +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 9)),
    axis.title.y = element_text(margin = margin(r = 8)),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(12, 46, 12, 12)
  )

write_csv_if_changed(unbalanced_plot_data, "../output/unbalanced_2006_2025_nonowned_controlled_share_plot_data.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, unbalanced_share_plot, width = 9.3, height = 5.8, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, unbalanced_share_plot, width = 9.3, height = 5.8, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/unbalanced_2006_2025_nonowned_controlled_share_timeseries.pdf")

balanced_firms <- plot_data |>
  filter(fiscal_year >= 2006, fiscal_year <= 2025) |>
  count(company, ticker, name = "usable_years") |>
  filter(usable_years == 20)

balanced_plot_data <- plot_data |>
  filter(fiscal_year >= 2006, fiscal_year <= 2025) |>
  semi_join(balanced_firms, by = c("company", "ticker")) |>
  mutate(
    balanced_group = case_when(
      ticker %in% c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR") ~ "Six-firm pilot",
      ticker == "TOL" ~ "Land-owner contrast",
      TRUE ~ "Other balanced builders"
    )
  ) |>
  arrange(ticker, fiscal_year)

if (nrow(balanced_plot_data) == 0) {
  stop("No usable observations for balanced 2006-2025 land-share plot.")
}

balanced_summary_data <- balanced_plot_data |>
  group_by(fiscal_year) |>
  summarise(
    firm_years = n(),
    mean_share = mean(nonowned_controlled_share, na.rm = TRUE),
    .groups = "drop"
  )

balanced_label_data <- balanced_plot_data |>
  group_by(ticker, company, balanced_group) |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(
    label_y = case_when(
      ticker == "NVR" ~ pmin(nonowned_controlled_share + 0.012, 1),
      ticker == "LEN" ~ pmax(nonowned_controlled_share - 0.018, 0),
      ticker == "TOL" ~ pmin(nonowned_controlled_share + 0.012, 1),
      ticker == "PHM" ~ pmax(nonowned_controlled_share - 0.014, 0),
      TRUE ~ nonowned_controlled_share
    )
  )

balanced_mean_label_data <- balanced_summary_data |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  mutate(label_y = pmin(mean_share + 0.025, 1))

balanced_share_plot <- ggplot() +
  geom_line(
    data = balanced_plot_data,
    aes(x = fiscal_year, y = nonowned_controlled_share, group = ticker),
    color = "grey62",
    linewidth = 0.55,
    alpha = 0.72,
    na.rm = TRUE
  ) +
  geom_point(
    data = balanced_plot_data,
    aes(x = fiscal_year, y = nonowned_controlled_share),
    color = "grey62",
    size = 1,
    stroke = 0,
    alpha = 0.72,
    na.rm = TRUE
  ) +
  geom_line(
    data = balanced_summary_data,
    aes(x = fiscal_year, y = mean_share),
    color = "#1f4e79",
    linewidth = 1.35,
    lineend = "round"
  ) +
  geom_point(
    data = balanced_summary_data,
    aes(x = fiscal_year, y = mean_share),
    color = "#1f4e79",
    size = 1.7,
    stroke = 0,
    alpha = 0.95
  ) +
  geom_text(
    data = balanced_label_data,
    aes(x = fiscal_year, y = label_y, label = ticker),
    hjust = 0,
    nudge_x = 0.18,
    size = 3,
    color = "grey38",
    show.legend = FALSE
  ) +
  geom_text(
    data = balanced_mean_label_data,
    aes(x = fiscal_year, y = label_y, label = "Mean"),
    hjust = 0,
    nudge_x = 0.18,
    size = 3.1,
    color = "#1f4e79",
    fontface = "bold",
    show.legend = FALSE
  ) +
  scale_x_continuous(
    breaks = seq(2006, 2025, by = 3),
    limits = c(2006, 2026.1),
    expand = c(0.01, 0)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(100 * x), "%"),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.1),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "Land-Light Share Among Balanced Public Homebuilders",
    subtitle = "Firm-specific 10-K extraction, balanced fiscal years 2006-2025; blue line is the unweighted firm mean",
    x = NULL,
    y = "Non-owned / controlled share",
    caption = "Grey lines are individual firms. Balanced sample: BZH, DHI, HOV, KBH, LEN, MHO, MTH, NVR, PHM, and TOL."
  ) +
  coord_cartesian(clip = "off") +
  theme_minimal(base_size = 11) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10.5, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.2, color = "grey35", hjust = 0, margin = margin(t = 9)),
    legend.position = "bottom",
    legend.justification = "left",
    axis.title.y = element_text(margin = margin(r = 8)),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(12, 46, 12, 12)
  )

write_csv_if_changed(balanced_plot_data, "../output/balanced_2006_2025_nonowned_controlled_share_plot_data.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, balanced_share_plot, width = 9.3, height = 5.8, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/balanced_2006_2025_nonowned_controlled_share_timeseries.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, balanced_share_plot, width = 9.3, height = 5.8, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/balanced_2006_2025_nonowned_controlled_share_timeseries.pdf")

cat("Wrote expanded builder land-share plot outputs to ../output\n")
