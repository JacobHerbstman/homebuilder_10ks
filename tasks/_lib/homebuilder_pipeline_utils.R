suppressPackageStartupMessages({
  library(arrow)
  library(readr)
  library(stringr)
})

copy_if_changed <- function(temp_path, out_path) {
  if (file.exists(out_path)) {
    old_hash <- unname(tools::md5sum(out_path))
    new_hash <- unname(tools::md5sum(temp_path))
    if (!is.na(old_hash) && !is.na(new_hash) && identical(old_hash, new_hash)) {
      unlink(temp_path)
      Sys.setFileTime(out_path, Sys.time())
      return(invisible(FALSE))
    }
    unlink(out_path)
  }

  file.rename(temp_path, out_path)
  invisible(TRUE)
}

write_csv_if_changed <- function(df, out_path) {
  temp_path <- tempfile(fileext = ".csv")
  write_csv(df, temp_path, na = "")
  copy_if_changed(temp_path, out_path)
}

write_parquet_if_changed <- function(df, out_path) {
  temp_path <- tempfile(fileext = ".parquet")
  write_parquet(df, temp_path)
  copy_if_changed(temp_path, out_path)
}

normalize_text_key <- function(x) {
  out <- str_to_lower(as.character(x))
  out <- iconv(out, to = "ASCII//TRANSLIT")
  out[is.na(out)] <- ""
  out <- str_replace_all(out, "&", " and ")
  out <- str_replace_all(out, "[^a-z0-9]+", " ")
  out <- str_squish(out)
  out[out == ""] <- NA_character_
  out
}
