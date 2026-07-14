# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/plot_six_firm_manual_land_panel/code")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

panel <- read_csv(
  "../input/six_firm_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    panel_use_flag = panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1),
    ticker = factor(ticker, levels = c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR")),
    pilot_builder_name = factor(
      pilot_builder_name,
      levels = c("D.R. Horton", "Lennar", "PulteGroup", "KB Home", "Hovnanian", "NVR")
    )
  )

plot_data <- panel |>
  filter(panel_use_flag, !is.na(nonowned_controlled_share)) |>
  mutate(nonowned_controlled_share_pct = 100 * nonowned_controlled_share) |>
  arrange(ticker, fiscal_year)

if (nrow(plot_data) == 0) {
  stop("No usable observations for six-firm land-share plot.")
}

label_data <- plot_data |>
  group_by(ticker, pilot_builder_name) |>
  slice_max(fiscal_year, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(
    label = as.character(ticker),
    label_y = case_when(
      ticker == "NVR" ~ pmin(nonowned_controlled_share + 0.006, 1),
      ticker == "LEN" ~ pmax(nonowned_controlled_share - 0.012, 0),
      TRUE ~ nonowned_controlled_share
    )
  )

firm_colors <- c(
  "DHI" = "#1f77b4",
  "LEN" = "#d62728",
  "PHM" = "#2ca02c",
  "KBH" = "#9467bd",
  "HOV" = "#8c564b",
  "NVR" = "#111111"
)

share_plot <- ggplot(
  plot_data,
  aes(
    x = fiscal_year,
    y = nonowned_controlled_share,
    color = ticker,
    group = ticker
  )
) +
  geom_line(linewidth = 0.85, na.rm = TRUE) +
  geom_point(size = 1.8, stroke = 0, na.rm = TRUE) +
  geom_text(
    data = label_data,
    aes(y = label_y, label = label),
    hjust = 0,
    nudge_x = 0.22,
    size = 3.4,
    show.legend = FALSE
  ) +
  scale_color_manual(values = firm_colors, guide = "none") +
  scale_x_continuous(
    breaks = seq(2006, 2025, by = 2),
    limits = c(2006, 2026.2),
    expand = c(0.01, 0)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(round(100 * x), "%"),
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.1),
    expand = c(0.01, 0)
  ) +
  labs(
    title = "Land-Light Share for Six Public Homebuilders",
    subtitle = "Hand-read 10-K disclosures, fiscal years 2006-2025",
    x = NULL,
    y = "Non-owned / controlled share",
    caption = paste(
      "Definitions vary by firm:",
      "DHI land/lot contracts, LEN controlled homesites, PHM/KBH/HOV optioned share,",
      "NVR LPA plus controlled JV lots from 2010 onward."
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
    plot.margin = margin(12, 40, 12, 12)
  )

write_csv_if_changed(plot_data, "../output/six_firm_nonowned_controlled_share_plot_data.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, share_plot, width = 8.4, height = 5.4, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/six_firm_nonowned_controlled_share_timeseries.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, share_plot, width = 8.4, height = 5.4, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/six_firm_nonowned_controlled_share_timeseries.pdf")

cat("Wrote six-firm manual land-share plot outputs to ../output\n")
