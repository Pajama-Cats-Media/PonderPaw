// Adaptor for flip book (images or PDF)

PJC.flipBookAdaptor = {
  onPlay: (lifecycle, page) => {
    if (PJC.playbook[page] && PJC.playbook[page].length > 0) {
      setTimeout(function () {
        PJC.fsm.changePage(page);
      });
    } else {
      console.log("nothing to play, show page only");
      setTimeout(function () {
        PJC.fsm.changePage(page);
      });
    }
  },
  onChangePage: (lifecycle, page) => {
    if (page != PJC.startPage && !PJC.context.started) {
      PJC.talkToNative(PJC.constants.USER_START);
      PJC.context.started = true;
    }

    PJC.talkToNative(PJC.constants.PAGE_PLAY);

    //unsub all actions
    if (PJC.currentActions) PJC.currentActions.unsubscribe();

    console.log("Change into the page: " + page + ", start to take actions");

    if (PJC.playbook[page]) {
      // for need to conver page name to index
      const index = _.findIndex(PJC.playbookOrder, (e) => e == page);
      PJC.flipbook.gotoPage(index);
      PJC.context.currentPage = page;
      setTimeout(function () {
        PJC.fsm.act(PJC.playbook[page]);
      }, PJC.config.act_delay);
    } else {
      console.error(
        "Can not find the page " +
        page +
        ". Do you give the name to a keyframe?"
      );
    }
  },
  showOrHide: (elem, show) => {
    //do nothing, since no extra control
  },
  playBookTransform: (data) => {
    if (data.playbookOrder) {
      data.playbook = _.pick(data.playbook, data.playbookOrder);
    }
    return data;
  },
};