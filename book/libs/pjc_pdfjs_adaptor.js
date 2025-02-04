PJC.nextPage = function () {
  if (PJC.pdfDoc && PJC.currentPage < PJC.totalPages) {
    PJC.currentPage++;
    PJC.renderPage(PJC.currentPage);
    console.log("Turn to the next page");
  }
};

PJC.prevPage = function () {
  if (PJC.pdfDoc && PJC.currentPage > 1) {
    PJC.currentPage--;
    PJC.renderPage(PJC.currentPage);
    console.log("Turn to the previous page");
  }
};

PJC.gotoPage = function (pageNumber) {
  if (PJC.pdfDoc && pageNumber >= 1 && pageNumber <= PJC.totalPages) {
    PJC.currentPage = pageNumber;
    PJC.renderPage(PJC.currentPage);
    console.log("Go to page " + pageNumber);
  }
};