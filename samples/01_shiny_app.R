# =============================================================================
# 01_shiny_app.R -- Minimal Shiny application
# =============================================================================
# Archetype demonstrated: Shiny Interactive Web Application
#   * ui     -> shiny_ui   (fluidPage layout + widgets)
#   * server -> shiny_server (reactive graph + renderPlot)
#
# Try:
#   rtrce explain samples/01_shiny_app.R
#   rtrce annotate samples/01_shiny_app.R      (preview, writes nothing)
# =============================================================================

library(shiny)

ui <- fluidPage(
  titlePanel("Dice roll simulator"),

  sidebarLayout(
    sidebarPanel(
      sliderInput("rolls", "Number of rolls:", min = 1, max = 1000, value = 100),
      selectInput("die", "Type of die:", choices = c("d6" = 6, "d20" = 20))
    ),
    mainPanel(
      plotOutput("histogram"),
      verbatimTextOutput("summary")
    )
  )
)

server <- function(input, output) {
  rolls <- reactive({
    sample(seq_len(as.integer(input$die)), size = input$rolls, replace = TRUE)
  })

  output$histogram <- renderPlot({
    hist(rolls(), breaks = "FD", main = "Distribution of rolls", xlab = "Face")
  })

  output$summary <- renderPrint({
    summary(rolls())
  })
}

shinyApp(ui = ui, server = server)
