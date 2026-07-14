# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/plot_nine_firm_land_light_timeseries/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
})

panel <- read_csv("../input/expanded_builder_2004_2025_land_panel.csv", show_col_types = FALSE) |>
  filter(
    ticker %in% c("TMHC", "TPH", "CCS", "LGIH", "GRBK", "DFH", "SDHC", "UHG", "LSEA"),
    fiscal_year %in% 2018:2025,
    in_universe_episode_window %in% TRUE,
    selected_main_plot_eligible %in% TRUE,
    !is.na(selected_nonowned_controlled_share)
  ) |>
  mutate(company_label = paste0(ticker))

year_means <- panel |>
  group_by(fiscal_year) |>
  summarise(mean_land_light_share = mean(selected_nonowned_controlled_share), .groups = "drop")

plot <- ggplot(panel, aes(fiscal_year, selected_nonowned_controlled_share, group = ticker)) +
  geom_line(color = "#a8adb3", linewidth = 0.65) +
  geom_point(color = "#737a82", size = 1.4) +
  geom_line(
    data = year_means,
    aes(fiscal_year, mean_land_light_share, group = 1),
    color = "#b33a32",
    linewidth = 1.25,
    inherit.aes = FALSE
  ) +
  geom_point(
    data = year_means,
    aes(fiscal_year, mean_land_light_share),
    color = "#b33a32",
    size = 2.2,
    inherit.aes = FALSE
  ) +
  geom_text(
    data = panel |>
      group_by(ticker) |>
      slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
      ungroup(),
    aes(label = company_label),
    color = "#34383d",
    hjust = -0.15,
    size = 3.2,
    check_overlap = TRUE
  ) +
  scale_x_continuous(breaks = 2018:2025, limits = c(2018, 2025.65)) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Land-Light Share for the Nine Additional Tier-1 Builders",
    subtitle = "Annual public-firm observations, 2018-2025; red line is the unweighted yearly mean",
    x = NULL,
    y = "Non-owned controlled share"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 11),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(12, 45, 12, 12)
  )

ggsave("../output/nine_firm_land_light_timeseries.png", plot, width = 10.5, height = 6.5, dpi = 220, bg = "white")
ggsave("../output/nine_firm_land_light_timeseries.pdf", plot, width = 10.5, height = 6.5)
