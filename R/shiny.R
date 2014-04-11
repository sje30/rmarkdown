#' Run a Shiny document
#'
#' Start a Shiny server for the given document, and render it for display.
#'
#' @param file Input file
#' @param auto_reload If \code{TRUE} (the default), automatically reload the
#'   Shiny application when the input file is changed.
#' @param shiny_args Additional arguments to \code{\link{runApp}}.
#' @param render_args Additional arguments to \code{\link{render}}.
#'
#' @return Invisible NULL.
#'
#' @details The \code{run} function runs a Shiny document by starting a Shiny
#'   server associated with the document. The \code{shiny_args} parameter can be
#'   used to configure the server; see the \code{\link{runApp}} documentation
#'   for details.
#'
#'   Once the server is started, the document will be rendered using
#'   \code{\link{render}}. The server will initiate a render of the document
#'   whenever necessary, so it is not necessary to call \code{run} every time
#'   the document changes: if \code{auto_reload} is \code{TRUE}, saving the
#'   document will trigger a render. You can also manually trigger a render by
#'   reloading the document in a Web browser.
#'
#' @note Unlike \code{\link{render}}, \code{run} does not render the document to
#'   a file on disk. To view the document, point a Web browser to the URL
#'   displayed when the server starts. In most cases a Web browser will be
#'   started automatically to view the document; see \code{launch.browser} in
#'   the \code{\link{runApp}} documentation for details.
#'
#' @examples
#' \dontrun{
#'
#' # Run the Shiny document "shiny_doc.Rmd" on port 8241
#'
#' rmarkdown::run("shiny_doc.Rmd", shiny_args = list(port = 8241))
#'
#' }
#' @export
run <- function(file, auto_reload = TRUE, shiny_args = NULL, render_args = NULL) {

  # create the Shiny server function
  server <- function(input, output, session) {

    # test for changes every half-second if requested
    reactive_file <- if (auto_reload)
      shiny::reactiveFileReader(500, session, file, identity)
    else
      function () { file }

    # when the file loads (or is changed), render to a temporary file, and
    # read the contents into a reactive value
    doc <- shiny::reactive({
      output_dest <- tempfile(fileext = ".html")

      # ensure that the document is not rendered to one page, and pass along
      # the HTML dependencies already satisfied by Shiny
      output_opts <- list(
        self_contained = FALSE,
        satisfied_dependencies =
          shiny::getProvidedHtmlDependencies())

      # merge our inputs with those supplied by the user and invoke render
      args <- merge_lists(list(input = reactive_file(),
                               output_file = output_dest,
                               output_options = output_opts,
                               runtime = "shiny"),
                          render_args)
      result_path <- do.call(render, args)

      # if we generated a folder of supporting files, map requests to those
      # files in the Shiny application
      resource_folder <- knitr_files_dir(output_dest)
      if (file.exists(resource_folder))
        addResourcePath(basename(resource_folder), resource_folder)

      # when the session ends, remove the rendered document and any supporting
      # files
      onReactiveDomainEnded(getDefaultReactiveDomain(), function() {
        unlink(result_path)
        unlink(resource_folder, recursive = TRUE)
      })
      paste(readLines(result_path), collapse="\n")
    })
    output$`__reactivedoc__` <- shiny::renderUI({
      shiny::HTML(doc())
    })
  }

  # combine the user-supplied list of Shiny arguments with our own and start
  # the Shiny server
  args <- merge_lists(
    list(list(ui = shiny::uiOutput("__reactivedoc__"),
              server = server)),
         shiny_args)
  do.call(shiny::runApp, args)
}
