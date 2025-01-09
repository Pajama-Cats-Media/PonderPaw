// Adaptor for Adobe animater html custom canvas

PJC.anAdaptor = {
  onPlay: (lifecycle, page) => {
    if (PJC.playbook[page] && PJC.playbook[page].length > 0) {
      if (PJC.scene && PJC.scene.gotoAndPlay) {
        setTimeout(function () {
          PJC.fsm.changePage(page);
        });
      } else {
        console.error(
          "Do not have scene context. load it in scene scripts first"
        );
      }
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

    //stop playing all videos in the page
    PJC.stopVideos();

    //restore all tweens into orignial status
    PJC.resetTweens();

    if (PJC.playbook[page]) {
      PJC.scene.gotoAndStop(page);

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
    // do not change invisible element
    if (elem && elem.visible) {
      if (show === undefined || show)
        createjs.Tween.get(elem).wait(PJC.config.asr_prepare).to(
          {
            alpha: 1,
          },
          300
        );
      //has to wait prepare time
      else
        createjs.Tween.get(elem).to(
          {
            alpha: 0,
          },
          0
        );
    }
  },
  playBookTransform: (data) => {
    if (data.playbookOrder) {
      data.playbook = _.pick(data.playbook, data.playbookOrder);
    }
    return data;
  },
};
