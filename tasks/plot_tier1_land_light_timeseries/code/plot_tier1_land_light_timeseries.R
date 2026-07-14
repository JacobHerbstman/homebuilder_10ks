# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/plot_tier1_land_light_timeseries/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(ggrepel)
  library(readr)
  library(scales)
})

panel <- read_csv("../input/expanded_builder_2004_2025_land_panel.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c(
      "DHI", "LEN", "PHM", "NVR", "KBH", "HOV",
      "BZH", "MHO", "MTH", "TOL", "MDC",
      "TMHC", "TPH", "CCS", "LGIH", "GRBK", "DFH", "SDHC", "UHG", "LSEA"
    ),
    fiscal_year %in% 2018:2025,
    in_universe_episode_window %in% TRUE,
    selected_main_plot_eligible %in% TRUE,
    !is.na(selected_nonowned_controlled_share)
  ) |>
  arrange(ticker, fiscal_year)

if (n_distinct(panel$ticker) != 20) {
  stop("Expected usable land-share observations for all 20 Tier-1 firms.")
}

year_means <- panel |>
  group_by(fiscal_year) |>
  summarise(
    firms = n(),
    mean_land_light_share = mean(selected_nonowned_controlled_share),
    .groups = "drop"
  )

label_data <- panel |>
  group_by(ticker) |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  ungroup()

plot <- ggplot(panel, aes(fiscal_year, selected_nonowned_controlled_share, group = ticker)) +
  geom_line(color = "#a8adb3", linewidth = 0.6) +
  geom_point(color = "#737a82", size = 1.25) +
  geom_line(
    data = year_means,
    aes(fiscal_year, mean_land_light_share, group = 1),
    color = "#b33a32",
    linewidth = 1.3,
    inherit.aes = FALSE
  ) +
  geom_point(
    data = year_means,
    aes(fiscal_year, mean_land_light_share),
    color = "#b33a32",
    size = 2.1,
    inherit.aes = FALSE
  ) +
  geom_text_repel(
    data = label_data,
    aes(fiscal_year, selected_nonowned_controlled_share, label = ticker),
    direction = "y",
    hjust = 0,
    nudge_x = 0.35,
    xlim = c(2025.15, 2026.55),
    min.segment.length = 0,
    segment.color = "grey65",
    segment.size = 0.25,
    box.padding = 0.12,
    point.padding = 0.05,
    max.overlaps = Inf,
    size = 3,
    color = "#34383d",
    seed = 410,
    inherit.aes = FALSE
  ) +
  scale_x_continuous(breaks = 2018:2025, limits = c(2018, 2026.65)) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Land-Light Share Across 20 Tier-1 Public Homebuilders",
    subtitle = "Annual public-firm observations, 2018-2025; red line is the unweighted yearly mean",
    x = NULL,
    y = "Non-owned controlled share",
    caption = "Lines begin and end with each firm's public reporting episode. Missing land-share years are not interpolated."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title.position = "plot",
    plot.caption.position = "plot",
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 11, margin = margin(b = 8)),
    plot.caption = element_text(size = 8.5, color = "grey35", hjust = 0, margin = margin(t = 8)),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(12, 85, 12, 12)
  )

ggsave("../output/tier1_land_light_timeseries.png", plot, width = 11.5, height = 8, dpi = 220, bg = "white")
ggsave("../output/tier1_land_light_timeseries.pdf", plot, width = 11.5, height = 8, bg = "white")
