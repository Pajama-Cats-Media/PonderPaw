// Adaptor for flip book (images or PDF)

PJC.nextPage =() => {
    //do nothing, since no extra control
    console.log("trun to the next page");
    PJC.flipbook.advance();
};

PJC.prevPage = () => {
    //do nothing, since no extra control
    console.log("trun to the prev page");
    PJC.flipbook.back();
};
