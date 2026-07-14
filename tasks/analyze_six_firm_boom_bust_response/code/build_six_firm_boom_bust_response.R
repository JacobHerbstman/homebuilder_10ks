# setwd("/Users/jacobherbstman/Desktop/homebuilder_10ks/tasks/analyze_six_firm_boom_bust_response/code")
# operating_start_year <- 2012L
# operating_end_year <- 2023L

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
})

source("../../_lib/homebuilder_pipeline_utils.R")

cli_args <- commandArgs(trailingOnly = TRUE)
if (interactive()) cli_args <- c(operating_start_year, operating_end_year)
if (length(cli_args) != 2) stop("Expected operating_start_year and operating_end_year.")
operating_start_year <- as.integer(cli_args[1])
operating_end_year <- as.integer(cli_args[2])

if (is.na(operating_start_year) || is.na(operating_end_year) || operating_start_year >= operating_end_year) {
  stop("Operating years must be valid integers with the start year before the end year.")
}

pilot_firms <- tibble(
  ticker = c("DHI", "LEN", "PHM", "KBH", "HOV", "NVR"),
  pilot_builder_name = c("D.R. Horton", "Lennar", "PulteGroup", "KB Home", "Hovnanian", "NVR"),
  firm_sort = seq_len(6)
)

operating <- read_csv(
  "../input/six_firm_2006_2025_operating_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  filter(fiscal_year %in% operating_start_year:operating_end_year) |>
  transmute(
    ticker,
    fiscal_year = as.integer(fiscal_year),
    orders_units = as.numeric(orders_units),
    orders_value_thousands = as.numeric(orders_value_thousands),
    orders_metric_label = orders_raw_label,
    orders_units_available = as.logical(orders_units_available),
    deliveries_units = as.numeric(deliveries_units),
    delivery_metric_label = deliveries_raw_label,
    backlog_units = as.numeric(backlog_units),
    backlog_value_thousands = as.numeric(backlog_value_thousands),
    cancellation_rate_pct = as.numeric(cancellation_rate_pct),
    active_communities = as.numeric(active_communities),
    average_community_count = as.numeric(average_community_count),
    operating_source_note = paste0(
      "Programmatic SEC 10-K extraction; method: ",
      extraction_method,
      "; accession: ",
      accession_number
    )
  )
growth_start_year <- operating_start_year + 1L

expected_operating <- expand_grid(
  ticker = pilot_firms$ticker,
  fiscal_year = operating_start_year:operating_end_year
)

missing_operating <- expected_operating |>
  anti_join(operating |> select(ticker, fiscal_year), by = c("ticker", "fiscal_year"))

if (nrow(missing_operating) > 0) {
  stop(paste(
    "Programmatic operating panel is missing rows:",
    paste(paste(missing_operating$ticker, missing_operating$fiscal_year, sep = "-"), collapse = ", ")
  ))
}

if (operating |> count(ticker, fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("Programmatic operating panel has duplicate firm-years.")
}

land_panel <- read_csv(
  "../input/six_firm_2006_2025_manual_land_panel.csv",
  show_col_types = FALSE,
  na = c("", "NA")
) |>
  mutate(
    fiscal_year = as.integer(fiscal_year),
    nonowned_controlled_share = as.numeric(nonowned_controlled_share),
    panel_use_flag = if_else(is.na(panel_use_flag), NA, panel_use_flag %in% c(TRUE, "TRUE", "true", "True", "1", 1))
  ) |>
  filter(ticker %in% pilot_firms$ticker, fiscal_year %in% operating_start_year:operating_end_year) |>
  select(
    ticker,
    fiscal_year,
    pilot_builder_name,
    measure_definition,
    unit_type,
    nonowned_controlled_share,
    owned_physical_count,
    nonowned_controlled_physical_count,
    total_physical_count,
    panel_use_flag,
    source_task,
    land_source_note = source_note,
    source_url,
    source_local_path
  )

if (land_panel |> count(ticker, fiscal_year) |> filter(n > 1) |> nrow() > 0) {
  stop("Six-firm land panel has duplicate firm-years in the operating diagnostic window.")
}

response_panel <- operating |>
  left_join(land_panel, by = c("ticker", "fiscal_year"), relationship = "one-to-one") |>
  left_join(
    pilot_firms |> select(ticker, pilot_builder_name_lookup = pilot_builder_name, firm_sort),
    by = "ticker",
    relationship = "many-to-one"
  ) |>
  mutate(
    pilot_builder_name = coalesce(pilot_builder_name, pilot_builder_name_lookup),
    omega = nonowned_controlled_share,
    omega_pct = 100 * omega,
    order_units_missing_expected = ticker == "HOV",
    order_units_available_for_growth = !is.na(orders_units) & orders_units_available,
    operating_source_quality = case_when(
      ticker == "HOV" ~ "programmatic_10k_tables_order_value_proxy_only",
      TRUE ~ "programmatic_10k_tables"
    )
  ) |>
  arrange(firm_sort, fiscal_year) |>
  group_by(ticker) |>
  mutate(
    omega_lag = lag(omega),
    omega_lag_pct = 100 * omega_lag,
    omega_base_year = omega[fiscal_year == operating_start_year][1],
    orders_units_lag = lag(orders_units),
    orders_value_thousands_lag = lag(orders_value_thousands),
    deliveries_units_lag = lag(deliveries_units),
    orders_units_growth = orders_units / orders_units_lag - 1,
    orders_value_growth = orders_value_thousands / orders_value_thousands_lag - 1,
    deliveries_units_growth = deliveries_units / deliveries_units_lag - 1,
    omega_change = omega - omega_lag,
    period_label = case_when(
      fiscal_year == operating_start_year ~ paste0("base_", operating_start_year),
      fiscal_year == 2021 ~ "boom_ramp_2020_to_2021",
      fiscal_year == 2022 ~ "rate_shock_2021_to_2022",
      fiscal_year == 2023 ~ "rebound_2022_to_2023",
      TRUE ~ paste0(fiscal_year - 1L, "_to_", fiscal_year)
    )
  ) |>
  ungroup() |>
  select(
    ticker,
    pilot_builder_name,
    fiscal_year,
    period_label,
    omega,
    omega_pct,
    omega_lag,
    omega_lag_pct,
    omega_base_year,
    omega_change,
    orders_units,
    orders_units_lag,
    orders_units_growth,
    orders_value_thousands,
    orders_value_thousands_lag,
    orders_value_growth,
    orders_metric_label,
    orders_units_available,
    order_units_missing_expected,
    deliveries_units,
    deliveries_units_lag,
    deliveries_units_growth,
    delivery_metric_label,
    backlog_units,
    backlog_value_thousands,
    cancellation_rate_pct,
    active_communities,
    average_community_count,
    measure_definition,
    unit_type,
    owned_physical_count,
    nonowned_controlled_physical_count,
    total_physical_count,
    panel_use_flag,
    operating_source_quality,
    operating_source_note,
    land_source_note,
    source_task,
    source_url,
    source_local_path
  )

growth_summary <- response_panel |>
  filter(fiscal_year > operating_start_year) |>
  transmute(
    ticker,
    pilot_builder_name,
    fiscal_year,
    period_label,
    lagged_omega = omega_lag,
    orders_units_growth,
    orders_value_growth,
    deliveries_units_growth,
    omega_change,
    order_units_note = if_else(
      is.na(orders_units_growth) & order_units_missing_expected,
      "HOV reports comparable annual net-contract value, not comparable annual net-contract units, in reviewed 10-K tables.",
      NA_character_
    )
  ) |>
  arrange(fiscal_year, desc(lagged_omega), ticker)

period_correlations <- growth_summary |>
  group_by(fiscal_year, period_label) |>
  summarise(
    order_unit_growth_firms = sum(!is.na(orders_units_growth) & !is.na(lagged_omega)),
    order_unit_growth_lagged_omega_correlation = if_else(
      order_unit_growth_firms >= 3,
      cor(lagged_omega, orders_units_growth, use = "complete.obs"),
      NA_real_
    ),
    delivery_growth_firms = sum(!is.na(deliveries_units_growth) & !is.na(lagged_omega)),
    delivery_growth_lagged_omega_correlation = if_else(
      delivery_growth_firms >= 3,
      cor(lagged_omega, deliveries_units_growth, use = "complete.obs"),
      NA_real_
    ),
    .groups = "drop"
  )

summary_wide <- growth_summary |>
  select(
    ticker,
    pilot_builder_name,
    fiscal_year,
    lagged_omega,
    orders_units_growth,
    orders_value_growth,
    deliveries_units_growth,
    omega_change
  ) |>
  pivot_wider(
    names_from = fiscal_year,
    values_from = c(lagged_omega, orders_units_growth, orders_value_growth, deliveries_units_growth, omega_change),
    names_glue = "{.value}_{fiscal_year}"
  ) |>
  left_join(
    response_panel |>
      filter(fiscal_year == operating_start_year) |>
      transmute(ticker, omega_base_year = omega),
    by = "ticker",
    relationship = "one-to-one"
  ) |>
  arrange(match(ticker, pilot_firms$ticker))

summary_output <- bind_rows(
  growth_summary |>
    mutate(summary_level = "firm_period") |>
    select(summary_level, everything()),
  period_correlations |>
    transmute(
      summary_level = "period_correlation",
      ticker = NA_character_,
      pilot_builder_name = NA_character_,
      fiscal_year,
      period_label,
      lagged_omega = NA_real_,
      orders_units_growth = order_unit_growth_lagged_omega_correlation,
      orders_value_growth = NA_real_,
      deliveries_units_growth = delivery_growth_lagged_omega_correlation,
      omega_change = NA_real_,
      order_units_note = paste0(
        "Correlation with lagged omega. order_unit_n=", order_unit_growth_firms,
        "; delivery_n=", delivery_growth_firms
      )
    )
) |>
  arrange(summary_level, fiscal_year, ticker)

audit <- bind_rows(
  tibble(
    audit_check = "operating_panel_rows",
    status = if_else(nrow(response_panel) == 6L * length(operating_start_year:operating_end_year), "ok", "fail"),
    value = as.character(nrow(response_panel)),
    detail = paste0("Expected six firms times fiscal years ", operating_start_year, "-", operating_end_year, ".")
  ),
  tibble(
    audit_check = "land_share_present",
    status = if_else(all(!is.na(response_panel$omega) & response_panel$panel_use_flag), "ok", "fail"),
    value = paste0(sum(!is.na(response_panel$omega)), "/", nrow(response_panel)),
    detail = "All diagnostic firm-years should have usable hand-coded land-light shares."
  ),
  tibble(
    audit_check = "orders_units_present",
    status = if_else(
      all(!is.na(response_panel$orders_units) | response_panel$order_units_missing_expected),
      "ok",
      "fail"
    ),
    value = paste0(sum(!is.na(response_panel$orders_units)), "/", nrow(response_panel)),
    detail = "HOV is the expected exception because reviewed 10-K tables provide net-contract dollars, not comparable annual net-contract units."
  ),
  tibble(
    audit_check = "deliveries_units_present",
    status = if_else(all(!is.na(response_panel$deliveries_units)), "ok", "fail"),
    value = paste0(sum(!is.na(response_panel$deliveries_units)), "/", nrow(response_panel)),
    detail = "Deliveries/closings/settlements are present for all six firms."
  ),
  tibble(
    audit_check = "growth_rows_order_units",
    status = if_else(
      sum(!is.na(response_panel$orders_units_growth)) == 5L * length(growth_start_year:operating_end_year),
      "ok",
      "fail"
    ),
    value = as.character(sum(!is.na(response_panel$orders_units_growth))),
    detail = paste0("Expected five firms times ", length(growth_start_year:operating_end_year), " transitions; HOV unit orders are intentionally missing.")
  ),
  tibble(
    audit_check = "growth_rows_deliveries",
    status = if_else(
      sum(!is.na(response_panel$deliveries_units_growth)) == 6L * length(growth_start_year:operating_end_year),
      "ok",
      "fail"
    ),
    value = as.character(sum(!is.na(response_panel$deliveries_units_growth))),
    detail = paste0("Expected six firms times ", length(growth_start_year:operating_end_year), " transitions.")
  ),
  tibble(
    audit_check = "share_range",
    status = if_else(all(response_panel$omega >= 0 & response_panel$omega <= 1), "ok", "fail"),
    value = paste0(round(min(response_panel$omega, na.rm = TRUE), 3), "-", round(max(response_panel$omega, na.rm = TRUE), 3)),
    detail = "Land-light share should remain in [0, 1]."
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

growth_years <- response_panel |>
  filter(fiscal_year %in% 2021:2023) |>
  mutate(
    ticker = factor(ticker, levels = pilot_firms$ticker),
    period_label = factor(
      period_label,
      levels = c("boom_ramp_2020_to_2021", "rate_shock_2021_to_2022", "rebound_2022_to_2023"),
      labels = c("2021 boom", "2022 rate shock", "2023 rebound")
    )
  )

recovery_years <- response_panel |>
  filter(fiscal_year %in% 2013:2019) |>
  mutate(
    ticker = factor(ticker, levels = pilot_firms$ticker),
    fiscal_year = factor(fiscal_year)
  )

order_unit_plot <- ggplot(
  growth_years |> filter(!is.na(orders_units_growth)),
  aes(x = omega_lag, y = orders_units_growth, color = ticker, label = ticker)
) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey55") +
  geom_point(size = 2.4) +
  geom_text(nudge_y = 0.018, size = 3.2, show.legend = FALSE) +
  facet_wrap(~period_label, nrow = 1) +
  scale_color_manual(values = firm_colors, guide = "none") +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0.2, 1.02), breaks = seq(0.2, 1, by = 0.2)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(-0.38, 0.28), breaks = seq(-0.3, 0.3, by = 0.1)) +
  labs(
    title = "Order Growth Versus Lagged Land-Light Share",
    subtitle = "Five firms with comparable net order units in reviewed 10-K tables",
    x = "Lagged non-owned controlled share",
    y = "Net order unit growth",
    caption = "HOV is omitted from this plot because reviewed 10-K tables gave comparable net-contract dollars, not annual net-contract units."
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

delivery_plot <- ggplot(
  growth_years,
  aes(x = omega_lag, y = deliveries_units_growth, color = ticker, label = ticker)
) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey55") +
  geom_point(size = 2.4) +
  geom_text(nudge_y = 0.016, size = 3.2, show.legend = FALSE) +
  facet_wrap(~period_label, nrow = 1) +
  scale_color_manual(values = firm_colors, guide = "none") +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0.2, 1.02), breaks = seq(0.2, 1, by = 0.2)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(-0.18, 0.32), breaks = seq(-0.15, 0.3, by = 0.1)) +
  labs(
    title = "Delivery Growth Versus Lagged Land-Light Share",
    subtitle = "Closings, deliveries, or settlements from reviewed 10-K tables",
    x = "Lagged non-owned controlled share",
    y = "Delivery unit growth",
    caption = "Delivery timing is slower moving than order timing because deliveries reflect prior backlog and construction cycle length."
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

order_unit_recovery_plot <- ggplot(
  recovery_years |> filter(!is.na(orders_units_growth)),
  aes(x = omega_lag, y = orders_units_growth, color = ticker, label = ticker)
) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey55") +
  geom_point(size = 2.1) +
  geom_text(nudge_y = 0.017, size = 2.9, show.legend = FALSE) +
  facet_wrap(~fiscal_year, nrow = 2) +
  scale_color_manual(values = firm_colors, guide = "none") +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1.02), breaks = seq(0, 1, by = 0.25)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(-0.2, 0.6), breaks = seq(-0.2, 0.6, by = 0.2)) +
  labs(
    title = "Order Growth Versus Lagged Land-Light Share, 2013-2019",
    subtitle = "Five firms with comparable net order units in reviewed 10-K tables",
    x = "Lagged non-owned controlled share",
    y = "Net order unit growth",
    caption = "HOV is omitted from this plot because reviewed 10-K tables gave comparable net-contract dollars, not annual net-contract units."
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

delivery_recovery_plot <- ggplot(
  recovery_years,
  aes(x = omega_lag, y = deliveries_units_growth, color = ticker, label = ticker)
) +
  geom_hline(yintercept = 0, linewidth = 0.35, color = "grey55") +
  geom_point(size = 2.1) +
  geom_text(nudge_y = 0.017, size = 2.9, show.legend = FALSE) +
  facet_wrap(~fiscal_year, nrow = 2) +
  scale_color_manual(values = firm_colors, guide = "none") +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1.02), breaks = seq(0, 1, by = 0.25)) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(-0.2, 0.6), breaks = seq(-0.2, 0.6, by = 0.2)) +
  labs(
    title = "Delivery Growth Versus Lagged Land-Light Share, 2013-2019",
    subtitle = "Closings, deliveries, or settlements from reviewed 10-K tables",
    x = "Lagged non-owned controlled share",
    y = "Delivery unit growth",
    caption = "Delivery timing is slower moving than order timing because deliveries reflect prior backlog and construction cycle length."
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

write_csv_if_changed(response_panel, "../output/six_firm_boom_bust_response_panel.csv")
write_csv_if_changed(summary_output, "../output/six_firm_boom_bust_response_summary.csv")
write_csv_if_changed(summary_wide, "../output/six_firm_boom_bust_response_summary_wide.csv")
write_csv_if_changed(audit, "../output/six_firm_boom_bust_response_audit.csv")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, order_unit_plot, width = 8.4, height = 4.8, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/six_firm_order_unit_growth_vs_lagged_omega.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, order_unit_plot, width = 8.4, height = 4.8, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/six_firm_order_unit_growth_vs_lagged_omega.pdf")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, delivery_plot, width = 8.4, height = 4.8, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/six_firm_delivery_growth_vs_lagged_omega.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, delivery_plot, width = 8.4, height = 4.8, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/six_firm_delivery_growth_vs_lagged_omega.pdf")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, order_unit_recovery_plot, width = 9.2, height = 6.4, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, order_unit_recovery_plot, width = 9.2, height = 6.4, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/six_firm_order_unit_growth_vs_lagged_omega_2013_2019.pdf")

temp_png <- tempfile(fileext = ".png")
ggsave(temp_png, delivery_recovery_plot, width = 9.2, height = 6.4, dpi = 300, bg = "white")
copy_if_changed(temp_png, "../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.png")

temp_pdf <- tempfile(fileext = ".pdf")
ggsave(temp_pdf, delivery_recovery_plot, width = 9.2, height = 6.4, device = grDevices::pdf, bg = "white")
copy_if_changed(temp_pdf, "../output/six_firm_delivery_growth_vs_lagged_omega_2013_2019.pdf")

cat("Wrote six-firm boom/bust response outputs to ../output\n")
