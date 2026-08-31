library(data.table)

# ============================================================
# CONFIGURACIÓN
# ============================================================

exp <- "912"
base_dir <- paste0("/home/ds/buckets/b1/exp/WFA", exp)
kaggle_dir <- file.path(base_dir, "kaggle")

competencia <- "data-mining-junior-2026-b"

cortes <- seq(1200, 1700, by = 100)

# ============================================================
# BUSCAR TODAS LAS PREDICCIONES
# ============================================================

archivos <- list.files(
  path = base_dir,
  pattern = "^prediccion\\.txt[0-9]+$",
  full.names = TRUE
)

if (length(archivos) == 0) {
  stop("No se encontraron archivos prediccion.txt<semilla>")
}

cat("Archivos de predicción encontrados:", length(archivos), "\n\n")

# Crear directorio Kaggle si no existe
dir.create(kaggle_dir, showWarnings = FALSE)

# ============================================================
# PROCESAR CADA SEMILLA
# ============================================================

for (archivo_prediccion in archivos) {

  # Extraigo la semilla del nombre
  nombre <- basename(archivo_prediccion)
  semilla <- sub("^prediccion\\.txt", "", nombre)

  cat("\n========================================\n")
  cat("SEMILLA:", semilla, "\n")
  cat("Archivo:", nombre, "\n")
  cat("========================================\n")

  # ----------------------------------------------------------
  # Leer predicciones
  # ----------------------------------------------------------

  tb_prediccion <- fread(archivo_prediccion)

  # ----------------------------------------------------------
  # Ordenar por probabilidad descendente
  # ----------------------------------------------------------

  setorder(tb_prediccion, -prob)

  # ----------------------------------------------------------
  # Generar y enviar cada corte
  # ----------------------------------------------------------

  for (envios in cortes) {

	archivo_kaggle <- file.path(
	  kaggle_dir,
	  paste0("KA", exp,"_", semilla, "_", envios, ".csv")
	)

    # --------------------------------------------------------
    # Generar archivo
    # --------------------------------------------------------

    tb_prediccion[, Predicted := 0L]
    tb_prediccion[1:envios, Predicted := 1L]

    fwrite(
      tb_prediccion[, list(numero_de_cliente, Predicted)],
      file = archivo_kaggle,
      sep = ","
    )

    cat(
      "\nEnviando:",
      basename(archivo_kaggle),
      "| semilla:", semilla,
      "| envíos:", envios, "\n"
    )

    # --------------------------------------------------------
    # Submit a Kaggle
    # --------------------------------------------------------

    comando <- paste(
      "kaggle competitions submit",
      "-c", competencia,
      "-f", shQuote(archivo_kaggle),
      "-m", shQuote(
        paste0(
          "WFA", exp, "envios=", envios,
          " semilla=", semilla
        )
      )
    )

    salida <- system(
      comando,
      intern = TRUE
    )

    cat(paste(salida, collapse = "\n"), "\n")

    # --------------------------------------------------------
    # Esperar antes del próximo submission
    # --------------------------------------------------------

    if (envios != max(cortes)) {
      cat("Esperando 30 segundos...\n")
      Sys.sleep(10)
    }
  }
}

cat("\n========================================\n")
cat("TODOS LOS ENVIOS FINALIZADOS\n")
cat("========================================\n")