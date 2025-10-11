library(shiny)
library(bslib)
library(tidyverse)
library(DT)

# Project root (one level up from app/)
root_dir <- normalizePath(file.path(".."), mustWork = FALSE)

# Expose reports/ as static resources for image display
reports_dir <- file.path(root_dir, "reports")
shiny::addResourcePath("reports", reports_dir)

artifacts_dir <- file.path(root_dir, "artifacts")

# Helper to run pipeline from the project root
run_pipeline <- function(quick = TRUE) {
  old <- getwd(); on.exit(setwd(old), add = TRUE)
  setwd(root_dir)
  options(dma.quick = quick)
  source(file.path("R", "install_packages.R"))
  source(file.path("R", "01_load_data.R"))
  source(file.path("R", "02_feature_engineering.R"))
  source(file.path("R", "03_train_models.R"))
  source(file.path("R", "04_evaluate.R"))
  source(file.path("R", "05_retention_strategy.R"))
}

ui <- page_sidebar(
  title = div(span("Customer Churn", class = "text-primary fw-bold"), span("Dashboard", class = "text-muted ms-2")),
  theme = bs_theme(
    version = 5,
    bootswatch = "cosmo",
    base_font = font_google("Inter"),
    heading_font = font_google("Poppins"),
    primary = "#3B82F6"
  ),
  sidebar = sidebar(
    h5("Run Pipeline"),
    checkboxInput("quick", NULL, value = TRUE),
    tags$small(class = "text-muted", "Quick mode (fast, approximate)"),
    actionButton("run", "Run / Refresh", class = "btn btn-primary mt-2", icon = icon("play")),
    hr(),
    tags$small(class = "text-muted", "Uses sample or synthetic data for instant runs."),
    hr(),
    downloadButton("download_data", "Download Current Data", class = "btn btn-outline-secondary btn-sm"),
    downloadButton("download_plots", "Download All Plots", class = "btn btn-outline-secondary btn-sm ms-2"),
    tags$small(class = "text-muted d-block mt-1", "Downloads the dataset used in the last run (artifacts/raw.csv)."),
    hr(),
    tags$small(class = "text-muted", "Artifacts are shown below in the main area.")
  ),
  
  # Global styles to improve readability and avoid inner scrollbars
  tags$head(tags$style(HTML('
    .card-body { overflow: visible !important; }
    .img-plot { width: 100%; height: auto; display: block; }
    .value-box { min-height: 120px; }
    .bslib-page-sidebar .main { padding-bottom: 1.5rem; }
  '))),

  div(
    
    # Header section
    card(
      class = "mb-3",
      card_header(tagList(h4("Overview"), tags$small(class = "text-muted", "Key metrics and model performance"))),
      uiOutput("kpi")
    ),

    # 2x2 plots grid
    layout_columns(
      col_widths = c(6,6),
      card(card_header("ROC Curve"), div(class = "p-2", uiOutput("roc_img")), div(class = "px-3 pb-3 text-muted small", "How well the model ranks positives above negatives across thresholds (TPR vs FPR).")),
      card(card_header("PR Curve"), div(class = "p-2", uiOutput("pr_img")), div(class = "px-3 pb-3 text-muted small", "Tradeoff between precision and recall, more informative with class imbalance.")),
      card(card_header("Confusion Matrix"), div(class = "p-2", uiOutput("cm_img")), div(class = "px-3 pb-3 text-muted small", "Predicted vs actual at the chosen threshold (optimized for F1).")),
      card(card_header("Profit Curve"), div(class = "p-2", uiOutput("profit_img")), div(class = "px-3 pb-3 text-muted small", "Expected profit vs percent of customers targeted based on churn probability."))
    ),

    # Artifacts tables full width
    card(
      class = "mt-3",
      card_header("Gains Curve"),
      div(class = "p-2", uiOutput("gains_img")),
      div(class = "px-3 pb-3 text-muted small", "Cumulative share of positives captured vs share of population targeted; higher curve indicates better lift over random.")
    ),
    card(
      class = "mt-3",
      card_header(tagList(h4("Artifacts"), tags$small(class = "text-muted", "Cross-validation scores and predictions preview"))),
      navset_tab(
        nav_panel("Scores", DTOutput("cv_table")),
        nav_panel("Predictions", DTOutput("pred_table"))
      )
    )
  )
)

server <- function(input, output, session) {
  
  # Provide dataset download of the current run
  output$download_data <- downloadHandler(
    filename = function() paste0("data-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".csv"),
    content = function(file) {
      path <- file.path(artifacts_dir, "raw.csv")
      if (!file.exists(path)) stop("No data available: run the pipeline first.")
      file.copy(path, file)
    }
  )

  # Zip and download all plots
  output$download_plots <- downloadHandler(
    filename = function() paste0("plots-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".zip"),
    content = function(file) {
        files <- c("roc_curve.png", "pr_curve.png", "confusion_matrix.png", "profit_curve.png", "gains_curve.png")
      full <- file.path(reports_dir, files)
      exist <- file.exists(full)
      if (!all(exist)) stop("Some plots are missing. Run the pipeline first.")
      # Use zip::zipr to avoid external zip dependency
      owd <- setwd(reports_dir); on.exit(setwd(owd), add = TRUE)
      zip::zipr(zipfile = file, files = files)
    }
  )
  
  # Track run completion time; use to trigger re-renders across outputs
  runStamp <- reactiveVal(NULL)
  hasRun <- reactive({ !is.null(runStamp()) })

  observeEvent(input$run, ignoreInit = TRUE, {
    output$run_log <- renderText({ "Running..." })
    withProgress(message = "Running pipeline...", value = 0, {
      tryCatch({
        # Always use default dataset path or synthetic
        options(dma.data_path = NULL)
        incProgress(0.3, detail = "Loading data")
        run_pipeline(quick = isTRUE(input$quick))
        incProgress(0.7, detail = "Generating reports")
        output$run_log <- renderText({ "Done." })
        runStamp(Sys.time())
        showNotification("Pipeline completed", type = "message", duration = 3)
      }, error = function(e) {
        runStamp(NULL)
        msg <- paste("Error:", conditionMessage(e))
        output$run_log <- renderText({ msg })
        showNotification(msg, type = "error", duration = 8)
      })
    })
  })

  metrics_path <- file.path(artifacts_dir, "metrics_test.csv")
  preds_path <- file.path(artifacts_dir, "predictions_test.csv")
  scores_path <- file.path(artifacts_dir, "cv_scores.csv")

  output$kpi <- renderUI({
    runStamp()  # depend on latest run
    if (!isTRUE(hasRun())) return(tags$em("Click Run / Refresh to see metrics."))
    if (!file.exists(metrics_path)) return(tags$em("Click Run / Refresh to see metrics."))
    m <- read_csv(metrics_path, show_col_types = FALSE)
    k <- function(metric) round(m$`.estimate`[m$`.metric` == metric][1], 3)
    layout_columns(
      col_widths = c(3,3,3,3),
        value_box(title = tags$div("Receiver Operating Characteristic (ROC) AUC", class = "text-muted small"), value = tags$div(k("roc_auc"), class = "fs-3 fw-bold"), showcase = icon("chart-area")),
        value_box(title = tags$div("Precision–Recall (PR) AUC", class = "text-muted small"), value = tags$div(k("pr_auc"), class = "fs-3 fw-bold"), showcase = icon("chart-line")),
      value_box(title = tags$div("Accuracy", class = "text-muted small"), value = tags$div(k("accuracy"), class = "fs-3 fw-bold"), showcase = icon("bullseye")),
        value_box(title = tags$div("F1 score", class = "text-muted small"), value = tags$div(k("f_meas"), class = "fs-3 fw-bold"), showcase = icon("balance-scale"))
    )
  })

  # Plot helpers
  render_png <- function(file_name) {
    file_path <- file.path(reports_dir, file_name)
    if (!file.exists(file_path)) return(tags$em("Not generated yet"))
    # Served via resource path 'reports'
    tags$img(src = file.path("reports", file_name), class = "img-plot", style = "border-radius:6px;")
  }

  placeholder <- function() { div(class = "text-muted p-3", "Click Run / Refresh to generate plots.") }

  output$roc_img    <- renderUI({ runStamp(); if (isTRUE(hasRun())) render_png("roc_curve.png") else placeholder() })
  output$pr_img     <- renderUI({ runStamp(); if (isTRUE(hasRun())) render_png("pr_curve.png") else placeholder() })
  output$cm_img     <- renderUI({ runStamp(); if (isTRUE(hasRun())) render_png("confusion_matrix.png") else placeholder() })
  output$profit_img <- renderUI({ runStamp(); if (isTRUE(hasRun())) render_png("profit_curve.png") else placeholder() })
  output$gains_img  <- renderUI({ runStamp(); if (isTRUE(hasRun())) render_png("gains_curve.png") else placeholder() })

  output$cv_table <- renderDT({
    runStamp()
    if (!isTRUE(hasRun())) return(datatable(tibble(Note = "Click Run / Refresh to see CV scores")))
    if (!file.exists(scores_path)) return(datatable(tibble(Note = "Run pipeline to see CV scores")))
    datatable(read_csv(scores_path, show_col_types = FALSE), options = list(pageLength = 5, scrollX = TRUE))
  })

  output$pred_table <- renderDT({
    runStamp()
    if (!isTRUE(hasRun())) return(datatable(tibble(Note = "Click Run / Refresh to see predictions")))
    if (!file.exists(preds_path)) return(datatable(tibble(Note = "Run pipeline to see predictions")))
    datatable(read_csv(preds_path, show_col_types = FALSE) |> head(500), options = list(pageLength = 10, scrollX = TRUE))
  })
}

shinyApp(ui, server)
