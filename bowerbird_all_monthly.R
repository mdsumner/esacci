library(bowerbird)
library(blueant)

datadir <- tempdir()
if (!file.exists(datadir)) dir.create(datadir)

srcset <- NULL

src0 <- bb_source(
  name = "ESA CCI, EOCIS Ocean Colour Product, and Copernicus Climate Change Service",
  id = "a7a591cc-1853-48f3-990c-5309c1d9d804",
  description = "Merged ocean colour from 1993 to present",
  doc_url = "https://climate.esa.int/en/projects/ocean-colour/,",
  citation = "",
  source_url = "https://www.oceancolour.org/thredds/catalog/cci/v6.0-release/geographic/monthly/all_products/catalog.html",
  license = "Please cite",
  method = list("bb_handler_rget", level = 2, accept_download =".*ESACCI-OC-L3S-OC_PRODUCTS-MERGED-1M_MONTHLY_4km_GEO_PML_OCx_QAA-.*-fv6.0.nc",
                no_host = FALSE, no_parent = TRUE),
  postprocess = NULL,
  access_function = "terra::rast",
  collection_size = 25,
  data_group = "ocean colour")

srcset <- rbind(srcset, src0)


cf <- bb_config(local_file_root = datadir)
cf <- bb_add(cf, srcset)
status <- bb_sync(cf, confirm_downloads_larger_than = NULL, dry_run = TRUE, verbose = TRUE)
files <- do.call(rbind, status$files)
files$query <- files$url
base <- "https://www.oceancolour.org/thredds"
files$size <- 0
files$exists <- FALSE

#catalog <- "https://www.oceancolour.org/thredds/catalog/cci/v6.0-release/geographic/monthly/all_products/1997/catalog.html?dataset=CCI_ALL-v6.0-Geographic%2Fmonthly%2Fall_products%2F1997%2FESACCI-OC-L3S-OC_PRODUCTS-MERGED-1M_MONTHLY_4km_GEO_PML_OCx_QAA-199709-fv6.0.nc"
#qu <- "https://www.oceancolour.org/browser/get.php?date=2024-01-01&product=chlor_a&period=monthly&format=netcdf&mapping=GEO&version=6"
#u <- "https://www.oceancolour.org/thredds/fileServer/cci//v6.0-release/geographic/monthly/chlor_a/2024/ESACCI-OC-L3S-CHLOR_A-MERGED-1M_MONTHLY_4km_GEO_PML_OCx-202401-fv6.0.nc"



for (i in seq_along(files$url)) {
 head <- (httr2::request(files$query[i]) |> httr2::req_perform())$body |> rawToChar()

 files$url[i] <- sprintf("%s/%s", base, gsub(">/thredds/", "", stringr::str_extract(head, ">/thredds/fileServer/.*nc")))

 files$exists[i] <- gdalraster::vsi_stat(sprintf("/vsicurl/%s", files$url[i]))
 if (files$exists[i]) {
   files$size[i] <- as.numeric(gdalraster::vsi_stat(sprintf("/vsicurl/%s", files$url[i]), "size"))
 } else {
   files$url[i] <- NA_character_
 }
 print(i)
}
files$date <- as.Date(sprintf("%s-15", stringr::str_extract(files$url, "[0-9]{6}")), "%Y%m-%d")
plot(files$date, files$size, type = "b", ylab = "file size in bytes")
title("ESA CCI, EOCIS Ocean Colour Product monthly chla file sizes")
arrow::write_parquet(files, "ESACCI-OC-L3S-CHLOR_A-MERGED-1M_MONTHLY_4km_GEO_PML_OCx-fv6.parquet")


