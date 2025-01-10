this.PJC = this.PJC || {}; //Global var for SDK, all functions put inside it.

(function () {
  "use strict";
  // message topics
  PJC.constants = {
    GET_ASR_RESULT: "get_asr_result",
    START_ASR: "start_asr",
    STOP_ASR: "stop_asr",
    RECOGNIZE_VOICE: "recognize_voice",
    UNRECOGNIZE_VOICE: "unrecognize_voice",
    BOOK_START: "book_start",
    BOOK_END: "book_end",
    PAGE_CHANGE: "page_change",
    USER_START: "user_start",
    PAGE_READY: "page_ready",
    PAGE_PLAY: "page_play",
    NEXT_PAGE: "next_page",
    PREV_PAGE: "prev_page",
    READY_WT: "ready_wt", //"ready speak" in FSM. ready for press and talk (only for walie talkie mode)
    STOP_WT: "stop_wt",
    PRESS_WT: "press_wt",
    RELEASE_WT: "release_wt",
    READ_START: "read_start", //use this for generic read: local file, tts, cloud...
    READ_END: "read_end",
    TTS_READ_START: "tts_read_start",
    TTS_READ_END: "tts_read_end",
    AI_SPEAK_START: "ai_speak_start",
    AI_SPEAK_END: "ai_speak_start",
    AI_LR_START: "ai_lr_start",
    AI_LR_END: "ai_lr_start",
    SOUND_START: "sound_start",
    SOUND_END: "sound_end",
  };
  // action names
  PJC.actionNames = {
    VOICE_INPUT: "voice_input",
    ANIMATION: "animation",
    READ: "read",
    AI_SPEAK: "ai_speak",
    AI_LISTEN_AND_RESPONSE: "ai_listen_and_response",
  };

  PJC.voiceInputMode = {
    DEFAULT: "default",
    AILR: "ailr",
    MULTI: "multi",
  };

  PJC.playbook = {}; // pages with actions in order
  PJC.startPage = "cover";
  PJC.mode = "default";
  PJC.actions = {};
  // it's fine to use seperated sounds, if the device supports
  PJC.soundSprites = {};
  PJC.multiModeParts = [];
  PJC.clips = {}; //map clip names to clip actions
  PJC.actionClips = {}; //map action names to rxjs obeservables
  PJC.drawnObjects = [];
  PJC.context = {
    stared: false,
    currentPage: PJC.startPage,
    log: [],
  };
  PJC.config = {
    auto_start: true,
    page_flip: "manual", //auto or manual
    page_wait: 3000,
    in_two_page_wait: 1000,
    page_change_throttle: 2000,
    allow_stop: false,
    start_delay: 1000,
    asr_retry: 1,
    asr_prepare: 500, //wait for asr ready to take voice input
    asr_gap: 1000, //delay after speak finish or timeout
    empty_gap: 200,
    asr_default_duration: 5000,
    wt_default_duration: 5000,
    wt_after_duration: 1500,
    wt_release_debounce: 2000,
    tts_start_delay: 250,
    tts_gap: 500,
    read_start_delay: 50,
    read_gap: 150,
    ais_start_delay: 500,
    ais_gap: 1000,
    ailr_start_delay: 500,
    ailr_gap: 1000,
    act_delay: 500,
    extra_processing: 2000,
    default_playbook: "default",
    default_language: "en-us",
    default_mode: "wt",
    no_action_wait: 3000,
    retry_factor: 0.1,
    retry_delay: 1000,
  };
  PJC.scene = null; // for scene context
  PJC.viewingTweens = []; // tween require to reset between pages
  Object.defineProperty(PJC, "pages", {
    get: function () {
      return _.keys(this.playbook);
    },
  });
})();

PJC.talkToNative = function (topic, data) {
  if (window.ReactNativeWebView) {
    window.ReactNativeWebView.postMessage(
      JSON.stringify({
        topic,
        data,
      })
    ); //this method only take one string param.
  }
  // for web browsers,  do nothing.
};

// playing "movie clips" (easyjs) rather than tween
// cb is for finish call, playing time have to be specified
PJC.playClip = function (obj, time, cb) {
  obj.gotoAndPlay(0);
  setTimeout(function () {
    obj.stop();
    cb();
  }, time);
};

//TODO: consider video in canvas
//name is the html element id of the video tag
// !The video feature has canvas issue, only for beta purpose
PJC.playVideo = function (name, cb) {
  setTimeout(function () {
    //prepare style, based on adobe animate createjs canvas html5 format
    let container = document.querySelector("#dom_overlay_container>div");
    container.style.width = "100%";
    container.style.height = "75%";
    container.style.top = "12.5%";
    container.style.bottom = "12.5%";

    let v = document.querySelector("#" + name);
    //TODO: check if v is a video
    v.style.width = "100%";
    v.style.height = "100%";
    v.style.display = "block";
    v.addEventListener("ended", cb, false);
    v.play();
  });
};

PJC.stopVideos = function () {
  document.querySelectorAll("video").forEach((v) => {
    v.pause();
    v.currentTime = 0;
    v.style.display = "none";
  });
};

PJC.resetTweens = function () {
  PJC.viewingTweens.forEach((item) => {
    if (item.gotoAndStop) item.gotoAndStop(0);
  });
  PJC.viewingTweens = [];
};

PJC.stimulateRecognized = function () {
  let message = JSON.stringify({
    topic: "get_asr_result",
    data: {
      similarity: 0.8,
      confidence: 0.5,
    },
  });
  window.postMessage(message);
};

PJC.stimulatePartialRecognized = function () {
  let message = JSON.stringify({
    topic: "get_asr_result",
    data: {
      mode: PJC.voiceInputMode.MULTI,
      similarityOfOptions: {
        a: 0.8,
        b: 0.6,
        c: 0.3,
        d: 0.1,
      },
      confidence: 0.6,
    },
  });
  window.postMessage(message);
};

PJC.stimulateNluWithParamRecognized = function () {
  let message = JSON.stringify({
    topic: "get_asr_result",
    data: {
      mode: "nlu",
      intent: "move",
      entity: ["100", "200"],
    },
  });
  window.postMessage(message);
};

PJC.stimulateUnrecognized = function () {
  let message = JSON.stringify({
    topic: "get_asr_result",
    data: {
      similarity: 0.3,
      confidence: 0.5,
    },
  });
  window.postMessage(message);
};

PJC.utoa = function (data) {
  // Encode the string to Base64 with URL encoding
  return btoa(encodeURIComponent(data));
};

PJC.atou = function (base64) {
  // Decode the Base64 string and URL decode it
  return decodeURIComponent(atob(base64));
};


PJC.testAction = function (actionName) {
  if (actionName && PJC.actions[actionName]) {
    PJC.animationActionHandler(actionName, PJC.actions[actionName]).subscribe(
      () => {
        console.log("Test to run the action: " + actionName);
      }
    );
  } else {
    console.error("No such action");
  }
};

PJC.getActionParam = function (name, index) {
  if (PJC.nluContext && PJC.nluContext[name]) {
    if (index === undefined) {
      return PJC.nluContext[name];
    } else {
      return PJC.nluContext[name][index];
    }
  }
  return null;
};

// finite state machine https://github.com/jakesgordon/javascript-state-machine
PJC.fsm = new StateMachine({
  init: "start",
  transitions: [
    {
      name: "play",
      from: "start",
      to: "pageReady",
    },
    {
      name: "act",
      from: "pageReady",
      to: "action",
    },
    {
      name: "asr",
      from: "action",
      to: "listen",
    },
    {
      name: "recognize",
      from: "listen",
      to: "action",
    },
    {
      name: "partialRecognize",
      from: "listen",
      to: "listen",
    },
    {
      name: "nluRecognize",
      from: "listen",
      to: "action",
    },
    {
      name: "asrTimeout",
      from: "listen",
      to: "action",
    },
    {
      name: "unrecognize",
      from: "listen",
      to: "action",
    },
    {
      name: "maxRetry",
      from: "listen",
      to: "action",
    },
    {
      name: "changePage",
      from: "pageReady",
      to: "pageReady",
    },
    {
      name: "startSpeak",
      from: "action",
      to: "speak",
    },
    {
      name: "finishSpeak",
      from: "speak",
      to: "action",
    },
    {
      name: "finishPage",
      from: "action",
      to: "pageReady",
    },
    {
      name: "finish",
      from: "pageReady",
      to: "finish",
    },
    {
      name: "startWt",
      from: "action",
      to: "speakReady",
    },
    {
      name: "finishWt",
      from: "speakReady",
      to: "action",
    },
    {
      name: "pressButton",
      from: "speakReady",
      to: "speak",
    },
    {
      name: "releaseButton",
      from: "speak",
      to: "speakReady",
    },
    {
      name: "wtRecognize",
      from: "speakReady",
      to: "action",
    },
    {
      name: "wtTimeout",
      from: "speakReady",
      to: "action",
    },
    {
      name: "wtUnrecognize",
      from: "speakReady",
      to: "action",
    },
    {
      name: "wtMaxRetry",
      from: "speakReady",
      to: "action",
    },
  ],
  methods: {
    onStep: function () {
      console.log("stepped");
    },
    onPlay: function (lifecycle, page) {
      console.log("Start to play");
      PJC.adaptor.onPlay(lifecycle, page);
    },
    onChangePage: function (lifecycle, page) {
      PJC.adaptor.onChangePage(lifecycle, page);
    },

    onAct: function (lifecycle, actions) {
      console.log("Start to act on the page");
      //hide page control
      PJC.showOrHide(PJC.nextButton, false);
      PJC.showOrHide(PJC.prevButton, false);
      if (actions && actions.length > 0) {
        PJC.playActions(actions); //Play one after another
      } else {
        setTimeout(function () {
          PJC.fsm.finishPage();
        });
      }
    },

    onStartWt: function (lifecycle, data, subscriber, retry) {
      if (retry && retry >= PJC.config.asr_retry) {
        console.log("wt max retry reached");
        setTimeout(function () {
          PJC.fsm.wtMaxRetry(data, subscriber);
        });
      } else {
        // wt interactive mode will not start listen until the button is manually pressed
        console.log("Under wt processing");
        PJC.talkToNative(PJC.constants.READY_WT, data);

        PJC.actWtStream = PJC.wt$
          .pipe(
            rxjs.operators.first(),
            rxjs.operators.timeout({
              first: data.duration || PJC.config.wt_default_duration,
              //each: PJC.config.wt_after_duration, // this will break press-release
              with: () =>
                rxjs.throwError(new Error("No press button detected, timeout")),
            })
          )
          .subscribe({
            next: (obj) => {
              console.log(obj);
              if (obj.topic == PJC.constants.PRESS_WT) {
                setTimeout(function () {
                  PJC.fsm.pressButton(data, subscriber, retry);
                });
              }
            },
            error: (err) => {
              console.log("finish wt processing due to timeout");
              console.log(err);
              PJC.actWtStream.unsubscribe();
              setTimeout(function () {
                PJC.fsm.wtTimeout(data, subscriber);
              });
            },
          });
      }
    },

    onFinishWt: function (lifecycle, data, subscriber, retry) {
      console.log("end wt ready");
      PJC.actWtStream.unsubscribe(); //try unsub again if timeout/error
      PJC.talkToNative(PJC.constants.STOP_WT, data);
      subscriber.next(data.name);
      subscriber.complete();
    },

    // similar to asr, but without timeout
    // open voice recognization, but wait to recognize until release the button
    onPressButton: function (lifecycle, data, subscriber, retry) {
      console.log("start to listen in wt");
      PJC.showOrHide(PJC.speechIndicator, true);
      PJC.talkToNative(PJC.constants.START_ASR, data);
      PJC.wtBuffer = [];
      PJC.activeAsr = PJC.asrStream$.subscribe((obj) => {
        console.log("voice inside wt press");
        PJC.wtBuffer.push(obj); //ugly but workable solution
      });

      // also listen to release button
      PJC.actWtStream = PJC.wtr$
        .pipe(
          rxjs.operators.first(),
          rxjs.operators.debounceTime(PJC.config.wt_release_debounce)
        )
        .subscribe({
          next: (obj) => {
            if (obj.topic == PJC.constants.RELEASE_WT) {
              setTimeout(function () {
                console.log(PJC.fsm.state);
                PJC.fsm.releaseButton(data, subscriber, retry);
              });
            }
          },
        });
    },

    // start to recognize after releas the button, unlike asr continues recognization
    // Only use the final reasult (onSpeechEnd in voice component at RN)
    onReleaseButton: function (lifecycle, data, subscriber, retry) {
      console.log("stop listening in wt");
      // if (PJC.actWtStream && PJC.actWtStream.unsubscribe instanceof Function)
      PJC.actWtStream.unsubscribe();
      PJC.talkToNative(PJC.constants.STOP_ASR);
      PJC.showOrHide(PJC.speechIndicator, false);

      if (data.mode == PJC.voiceInputMode.DEFAULT) {
        if (PJC.wtBuffer.length) {
          let maxOne = _.maxBy(PJC.wtBuffer, function (item) {
            return item.data.similarity;
          });
          if (maxOne.data.similarity >= maxOne.data.confidence) {
            setTimeout(function () {
              PJC.fsm.wtRecognize(data, maxOne, subscriber);
            });
          } else {
            setTimeout(function () {
              PJC.fsm.wtUnrecognize(data, maxOne, subscriber, retry);
            });
          }
        } else {
          // no sound detected, retry?
          setTimeout(function () {
            PJC.wtBuffer = [];
            PJC.fsm.finishWt(data, subscriber);
          });
        }
      } else if (data.mode == PJC.voiceInputMode.AILR) {
        console.log("AILR mode");
        setTimeout(function () {
          PJC.wtBuffer = [];
          PJC.fsm.finishWt(data, subscriber);
        });
      }
    },
    onWtRecognize: function (lifecycle, data, result, subscriber) {
      console.log("recognized voice from wt");
      PJC.talkToNative(PJC.constants.RECOGNIZE_VOICE, data);
      PJC.ackRecognized();
      // play success action
      let actionName = data.successAction;
      if (actionName && PJC.actions[actionName]) {
        PJC.animationActionHandler(
          actionName,
          PJC.actions[actionName]
        ).subscribe(() => {
          console.log("Voice recognized, replay action: " + actionName);
          subscriber.next();
          subscriber.complete();
        });
      } else {
        subscriber.next();
        subscriber.complete();
      }
    },
    onWtUnrecognize: function (lifecycle, data, result, subscriber, retry) {
      console.log("did not recognize voice from wt");
      PJC.talkToNative(PJC.constants.UNRECOGNIZE_VOICE, data);

      if (retry === undefined) {
        retry = 0;
      } else {
        retry = retry + 1;
      }

      // reduce difficult a liitle bit
      let deduction = retry >= 0 ? (retry + 1) * PJC.config.retry_factor : 0;
      data.confidence = data.confidence - deduction;
      let actionName = data.failureAction;
      if (actionName && PJC.actions[actionName]) {
        if (retry < PJC.config.asr_retry) {
          setTimeout(function () {
            PJC.animationActionHandler(
              actionName,
              PJC.actions[actionName]
            ).subscribe(() => {
              console.log("Voice unrecognized, replay action: " + actionName);
              PJC.fsm.startWt(data, subscriber, retry);
            });
          }, PJC.config.retry_delay);
        } else {
          setTimeout(function () {
            PJC.fsm.startWt(data, subscriber, retry);
          });
        }
      } else {
        setTimeout(function () {
          data.isRetry = true;
          PJC.fsm.startWt(data, subscriber, retry);
        }, PJC.config.no_action_wait); //wait longer if no follow up actions [important], otherwise wt button appeared too soon
      }
    },

    onAsr: function (lifecycle, data, subscriber, retry) {
      if (retry !== undefined) {
        console.log("retry " + retry + " time(s)");
        data.isRetry = true;
        // add an indicator for retry
        if (PJC.speechIndicator) {
          PJC.speechIndicator.gotoAndStop("unrecognized");
        }
      } else {
        if (PJC.speechIndicator) {
          PJC.speechIndicator.gotoAndStop("default");
        }
      }

      if (retry && retry >= PJC.config.asr_retry) {
        console.log("max retry reached");
        setTimeout(function () {
          PJC.fsm.maxRetry(data, subscriber);
        });
      } else {
        console.log("start to listen voice");
        PJC.showOrHide(PJC.speechIndicator, true);
        // start asr
        // default mode is "max similarity" for read together
        if (!data.mode || data.mode == "default") {
          // in timeout data.duration, use the max similarity as the result
          // if fsm in listening state, process ASR data, otherwise abandon them
          PJC.activeAsr = PJC.asrStream$
            .pipe(
              rxjs.operators.bufferTime(
                data.duration || PJC.config.asr_default_duration
              ),
              rxjs.operators.timeout({
                each: data.duration || PJC.config.asr_default_duration,
                with: () =>
                  rxjs.throwError(
                    new Error("No voice input detected, timeout")
                  ),
              })
            )
            .subscribe((obj) => {
              if (obj.length > 0) {
                let maxOne = _.maxBy(obj, function (item) {
                  return item.data.similarity;
                });
                console.log(maxOne);
                if (maxOne.data.similarity >= maxOne.data.confidence) {
                  setTimeout(function () {
                    PJC.fsm.recognize(data, maxOne, subscriber);
                  });
                } else {
                  setTimeout(function () {
                    PJC.fsm.unrecognize(data, maxOne, subscriber, retry);
                  });
                }
              } else {
                setTimeout(function () {
                  PJC.fsm.asrTimeout(data, subscriber);
                });
              }
            });
        } else {
          console.error("unsupported model:" + data.model);
        }
      } // add more experience mode here

      PJC.talkToNative(PJC.constants.START_ASR, data);
    },
    onLeaveListen: function () {
      console.log("stop to listen voice");
      //stop asr
      PJC.activeAsr.unsubscribe();
      PJC.talkToNative(PJC.constants.STOP_ASR);
      PJC.showOrHide(PJC.speechIndicator, false);
    },
    onRecognize: function (lifecycle, data, result, subscriber) {
      console.log("recognized voice");
      PJC.talkToNative(PJC.constants.RECOGNIZE_VOICE, data);
      PJC.ackRecognized();
      // play success action
      let actionName = data.successAction;
      if (actionName && PJC.actions[actionName]) {
        PJC.animationActionHandler(
          actionName,
          PJC.actions[actionName]
        ).subscribe(() => {
          console.log("Voice recognized, replay action: " + actionName);
          subscriber.next();
          subscriber.complete();
        });
      } else {
        subscriber.next();
        subscriber.complete();
      }
    },
    onUnrecognize: function (lifecycle, data, result, subscriber, retry) {
      console.log("did not recognize voice");
      PJC.talkToNative(PJC.constants.UNRECOGNIZE_VOICE, data);

      if (retry === undefined) {
        retry = 0;
      } else {
        retry = retry + 1;
      }

      // reduce difficult a liitle bit
      let deduction = retry >= 0 ? (retry + 1) * PJC.config.retry_factor : 0;
      data.confidence = data.confidence - deduction;

      let actionName = data.failureAction;
      if (actionName && PJC.actions[actionName]) {
        if (retry < PJC.config.asr_retry) {
          setTimeout(function () {
            PJC.animationActionHandler(
              actionName,
              PJC.actions[actionName]
            ).subscribe(() => {
              console.log("Voice unrecognized, replay action: " + actionName);
              PJC.fsm.asr(data, subscriber, retry);
            });
          }, PJC.config.asr_gap);
        } else {
          setTimeout(function () {
            PJC.fsm.asr(data, subscriber, retry);
          });
        }
      } else {
        setTimeout(function () {
          PJC.fsm.asr(data, subscriber, retry);
        });
      }
    },
    onPartialRecognize: function (lifecycle, data, option, subscriber) {
      console.log("recognized partial option");
      console.dir(data);
      //PJC.talkToNative(PJC.constants.RECOGNIZE_VOICE, data);
      //PJC.ackRecognized();
      // play this option's action (if all options are done, go to finish)
      let actionName = data.actions[option];
      if (actionName && PJC.actions[actionName]) {
        PJC.animationActionHandler(
          actionName,
          PJC.actions[actionName]
        ).subscribe(() => {
          console.log(
            "Voice partial option recognized, replay action: " + actionName
          );

          if (PJC.multiModeParts.length < Object.keys(data.actions).length) {
            PJC.multiModeParts.push(option);
            PJC.multiModeParts = _.uniq(PJC.multiModeParts);
          } else {
            // complete if all options are triggered
            PJC.multiModeParts = [];
            //TODO:
            // cancel timeout

            // subscriber.next();
            // subscriber.complete();
          }
        });
      } else {
        subscriber.next();
        subscriber.complete();
      }
    },
    onNluRecognize: function (lifecycle, data, result, subscriber) {
      console.log("recognized NLU:");
      console.dir(result);

      //[!Important] Use this to get params in clips
      PJC.nluContext = {};

      PJC.talkToNative(PJC.constants.RECOGNIZE_VOICE, data);
      PJC.ackRecognized();

      if (result.intent) {
        const matchedAction = _.find(data.actions, (action) => {
          // if no expected entity, only compare intent
          if (!action.entity || action.entity.length == 0) {
            return action.intent === result.intent;
          }
          return (
            action.intent === result.intent &&
            _.difference(action.entity, result.entity).length === 0 //result.entity includes action.entity
          );
        });

        console.log(matchedAction);

        if (matchedAction) {
          const actionName = matchedAction.action;
          // need to write nlu param to context (if any)
          // prepare context for easy consumption
          if (matchedAction.params) {
            const kv = _.entries(matchedAction.params);
            kv.forEach((item) => {
              if (item[1].index === undefined)
                PJC.nluContext[item[0]] = result[item[1].key];
              else PJC.nluContext[item[0]] = result[item[1].key][item[1].index];
            });
            PJC.nluContext["_raw"] = result;
            console.log("Set nlu params as:");
            console.log(PJC.nluContext);
          }

          if (actionName && PJC.actions[actionName]) {
            PJC.animationActionHandler(
              actionName,
              PJC.actions[actionName]
            ).subscribe(() => {
              console.log("NLU recognized, replay action: " + actionName);
              subscriber.next();
              subscriber.complete();
            });
          } else {
            subscriber.next();
            subscriber.complete();
          }
        } else {
          //TODO: show something to notice user?
          subscriber.next();
          subscriber.complete();
        }
      } else {
        subscriber.next();
        subscriber.complete();
      }
    },
    onFinishPage: function () {
      console.log("The page is done, waiting to change another");
      const currentIndex = _.findIndex(
        PJC.pages,
        (e) => e === PJC.context.currentPage
      );
      // add data of page info to help show page control
      PJC.talkToNative(PJC.constants.PAGE_READY, {
        current: currentIndex,
        total: PJC.pages.length,
      });

      //show buildin page control
      if (
        PJC.context.currentPage != PJC.pages[PJC.pages.length - 1] &&
        PJC.context.currentPage != PJC.pages[0]
      ) {
        let showButtons = true;

        // If there is a next page, auto flip if set so
        if (PJC.config.page_flip == "auto") {
          setTimeout(function () {
            PJC.nextPage();
          }, PJC.config.page_wait);
        } else if (PJC.config.page_flip == "manual") {
          if (currentIndex % 2 == 1) {
            showButons = false;
            setTimeout(function () {
              PJC.nextPage();
            }, PJC.config.in_two_page_wait);
          }
  
          if (showButtons) {
            PJC.showOrHide(PJC.prevButton, true);
            PJC.showOrHide(PJC.nextButton, true);
          }
        } else {
          console.error("unsupported flip mode: " + PJC.config.page_flip );
        }
      } else if (PJC.context.currentPage != PJC.pages[PJC.pages.length - 1]) {
        PJC.showOrHide(PJC.nextButton, true);
      } else if (PJC.context.currentPage != PJC.pages[0]) {
        PJC.showOrHide(PJC.prevButton, true);
      }

      //Jump to finish once last page is reach
      if (PJC.context.currentPage == PJC.pages[PJC.pages.length - 1]) {
        setTimeout(function () {
          PJC.fsm.finish();
        }, PJC.config.page_wait);
      }
    },
    onFinish: function () {
      console.log("The whole interaction is finished");
      PJC.talkToNative(PJC.constants.BOOK_END);
    },
    onPageReady: function (lifecycle) {
      console.log("In page ready state now");
    },
    onAsrTimeout: function (lifecycle, data, subscriber) {
      console.log("ASR timeout");
      subscriber.next(data.name);
      subscriber.complete();
    },
    onMaxRetry: function (lifecycle, data, subscriber) {
      console.log("ASR retried max times, move on");
      subscriber.next(data.name);
      subscriber.complete();
    },
    onStopWt: function (lifecycle, data, subscriber) {
      console.log("Stop WT");
      subscriber.next(data.name);
      subscriber.complete();
    },
    onWtTimeout: function (lifecycle, data, subscriber) {
      console.log("WT timeout");
      PJC.talkToNative(PJC.constants.STOP_WT, data);
      subscriber.next(data.name);
      subscriber.complete();
    },
    onWtMaxRetry: function (lifecycle, data, subscriber) {
      console.log("WT retried max times, move on");
      subscriber.next(data.name);
      subscriber.complete();
    },
  },
});

PJC.animationActionHandler = function (name, action) {
  "use strict";
  let rx = new rxjs.Observable((subscriber) => {
    // TODO: using nested obeservables, put merged clips as operators in pipe
    if (PJC.actionClips && PJC.actionClips[name].length) {
      rxjs.merge(...PJC.actionClips[name]).subscribe(
        (clip) => console.log("Clip played: " + clip),
        (err) => {},
        () => {
          console.log("All clips in the actiion " + name + " are played.");
          subscriber.next(name);
          subscriber.complete();
        }
      );
    }
  });
  return rx;
};

// detect whether the voice input is similar to the expected words (for reading together experience)
// for understand the answer from the voice input (for answer and question experience)
// output one or more events (using data.mode = 'multi')
PJC.voiceInputActionHandler = function (name, action) {
  "use strict";
  // send subscriber to fsm and it will return in either recognize, unrecognize, or timeout...
  let startListen = null;
  if (PJC.mode == "wt") {
    //if wt mode, press button before asr
    startListen = new rxjs.Observable((subscriber) => {
      console.log("start to wt ready " + name);
      PJC.fsm.startWt(action.data, subscriber);
    });
  } else {
    startListen = new rxjs.Observable((subscriber) => {
      console.log("start to record " + name);
      PJC.fsm.asr(action.data, subscriber);
    });
  }

  let waitInput = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.asr_gap);
  }); // ! important to add a minial wait otherwise, use voice input as page end will cause issues.

  return rxjs.concat(startListen, waitInput);
};

// more action handels for chatgpt integration
// PJC.readActionHandler = function (name, action) {
//   "use strict";
//   // Send text to tss engine once fire the action
//   const tts = new rxjs.Observable((subscriber) => {
//     setTimeout(function () {
//       console.log("TTS read action:" + name);
//       // send message to native to start tts read
//       PJC.talkToNative(PJC.constants.TTS_READ_START, action.data);
//       subscriber.next(name);
//       subscriber.complete();
//     }, PJC.config.tts_start_delay);
//   });

//   //start tts read, then wait until receive the finish singal or timeout
//   const ttsf = PJC.ttsf$.pipe(
//     rxjs.operators.tap(console.log),
//     rxjs.operators.first()
//   );

//   const erx = new rxjs.Observable((subscriber) => {
//     setTimeout(function () {
//       subscriber.next(name);
//       subscriber.complete();
//     }, PJC.config.tts_gap);
//   });

//   return rxjs.concat(tts, ttsf, erx);
// };

// generic read
PJC.readActionHandler = function (name, action) {
  "use strict";
  // Send text to tss engine once fire the action
  const readAction = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      console.log("Read action:" + name);
      // send message to native to start read
      PJC.talkToNative(PJC.constants.READ_START, action.data);
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.read_start_delay);
  });

  //start read, then wait until receive the finish stop singal (TODO: add timeout)
  const readf = PJC.readf$.pipe(
    rxjs.operators.tap(console.log),
    rxjs.operators.first()
  );

  const erx = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.read_gap);
  });

  return rxjs.concat(readAction, readf, erx);
};

PJC.aiSpeakActionHandler = function (name, action) {
  "use strict";

  const ais = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      console.log("AI speak action:" + name);
      // send message to native to start tts read
      PJC.talkToNative(PJC.constants.AI_SPEAK_START, action.data);
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.ais_start_delay);
  });

  //start tts read, then wait until receive the finish singal or timeout
  //here we reuse tts end event (since always read out)
  const ttsf = PJC.ttsf$.pipe(
    rxjs.operators.tap(console.log),
    rxjs.operators.first()
  );

  let erx = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.ais_gap);
  });
  return rxjs.concat(ais, ttsf, erx);
};

// PJC.aiListenAndResponseActionHandler = function (name, action) {
//   "use strict";

//   const ailr = new rxjs.Observable((subscriber) => {
//     setTimeout(function () {
//       console.log("AI listen and response action:" + name);
//       // send message to native to start tts read
//       PJC.talkToNative(PJC.constants.AI_LR_START, action.data);
//       subscriber.next(name);
//       subscriber.complete();
//     }, PJC.config.ailr_start_delay);
//   });

//   let erx = new rxjs.Observable((subscriber) => {
//     setTimeout(function () {
//       subscriber.next(name);
//       subscriber.complete();
//     }, PJC.config.ailr_gap);
//   });

//   return rxjs.concat(ailr, erx);
// };

PJC.aiListenAndResponseActionHandler = function (name, action) {
  "use strict";
  // send subscriber to fsm and it will return in either recognize, unrecognize, or timeout...
  let startListen = null;
  if (PJC.mode == "wt") {
    //if wt mode, press button before asr
    startListen = new rxjs.Observable((subscriber) => {
      action.data.mode = PJC.voiceInputMode.AILR; // set mode to ailr for voice special processing
      PJC.talkToNative(PJC.constants.AI_LR_START, action.data);
      console.log("start to AI LR wt ready " + name);
      PJC.fsm.startWt(action.data, subscriber);
    });
  } else {
    startListen = new rxjs.Observable((subscriber) => {
      PJC.talkToNative(PJC.constants.AI_LR_START, action.data);
      console.log("start AI LR record " + name);
      PJC.fsm.asr(action.data, subscriber);
    });
  }

  const ttsf = PJC.ttsf$.pipe(
    rxjs.operators.tap(console.log),
    rxjs.operators.first()
  );

  let waitInput = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.ailr_gap);
  });

  return rxjs.concat(startListen, ttsf, waitInput);
};

PJC.unknownActionHandler = function (name, action) {
  "use strict";
  let rx = new rxjs.Observable((subscriber) => {
    setTimeout(function () {
      console.log("unknown action type:" + action.type);
      subscriber.next(name);
      subscriber.complete();
    }, PJC.config.empty_gap);
  });
  return rxjs.concat(rx, rx); //need at least two concated obserable to make it work
};

PJC.playActions = function (arr) {
  "use strict";

  let actionChain = [];

  // Using rxjs to chain them (concat obeservables)
  if (arr.length > 0) {
    arr.forEach((item) => {
      if (PJC.actions[item]) {
        if (PJC.actions[item].type == PJC.actionNames.ANIMATION) {
          actionChain.push(PJC.animationActionHandler(item, PJC.actions[item]));
        } else if (PJC.actions[item].type == PJC.actionNames.VOICE_INPUT) {
          let action = PJC.actions[item];
          action.data.name = item;
          if (!action.data.mode) {
            action.data.mode = PJC.voiceInputMode.DEFAULT;
          }
          actionChain.push(PJC.voiceInputActionHandler(item, action));
        } else if (PJC.actions[item].type == PJC.actionNames.READ) {
          actionChain.push(PJC.readActionHandler(item, PJC.actions[item]));
        } else if (PJC.actions[item].type == PJC.actionNames.AI_SPEAK) {
          actionChain.push(PJC.aiSpeakActionHandler(item, PJC.actions[item]));
        } else if (
          PJC.actions[item].type == PJC.actionNames.AI_LISTEN_AND_RESPONSE
        ) {
          actionChain.push(
            PJC.aiListenAndResponseActionHandler(item, PJC.actions[item])
          );
        } else {
          actionChain.push(PJC.unknownActionHandler(item, PJC.actions[item]));
        }
      }
    });
  }

  PJC.currentActions = rxjs.concat(...actionChain).subscribe(
    (action) => console.log("Action finished: " + action),
    (err) => {},
    () => {
      console.log("All actions in a page are finished."); //TODO: do not help multi mode
      PJC.fsm.finishPage();
    }
  );
};

// Each clip is a function with complete callback
// name: the clip name in actions' definition
// clip: animation with/without sound or sound only
PJC.addClip = function (name, clip) {
  "use strict";
  PJC.clips[name] = clip;
};

// TODO: If actions are not fully completed, abandon unfinished and change into the new page
// throttle a long time to avoid click twince
PJC.nextPage = _.throttle(function () {
  let index = _.indexOf(PJC.pages, PJC.context.currentPage);
  if (index >= 0 && index < PJC.pages.length - 1) {
    PJC.fsm.changePage(PJC.pages[index + 1]);
  } else {
    console.log("Can not find the page or already in the last page");
  }
}, PJC.config.page_change_throttle);

PJC.prevPage = _.throttle(function () {
  let index = _.indexOf(PJC.pages, PJC.context.currentPage);
  if (index >= 1 && index < PJC.pages.length) {
    PJC.fsm.changePage(PJC.pages[index - 1]);
  } else {
    console.log("Can not find the page or already in the first page");
  }
}, PJC.config.page_change_throttle);

//The name of the sound resource have to be in the library and offset, duration of the sprite
//cb is the complete callback
//Note: sound sprite is only necessary for old iOS. Animators can use seperate sounds as well
//if no start and duration, play the whole sound
PJC.playSoundSprite = function (name, start, duration, cb) {
  // use native sound player, keep the createjs sound player for web browser testing
  if (window.ReactNativeWebView) {
    PJC.talkToNative(PJC.constants.SOUND_START, { name, start, duration });
    setTimeout(cb, 3000);
  } else {
    var instance = createjs.Sound.play(name, {
      startTime: start,
      duration: duration,
    });
    instance.on("complete", cb);
  }
};

// param show true for show, false for hide
PJC.showOrHide = function (elem, show) {
  // do not change invisible element
  PJC.adaptor.showOrHide(elem, show);
};

PJC.ackRecognized = function () {
  if (PJC.asrStatus) {
    createjs.Tween.get(PJC.asrStatus)
      .to(
        {
          alpha: 1,
        },
        100
      )
      .wait(500)
      .to(
        {
          alpha: 0,
        },
        100
      );
  }
};

PJC.loadBook = function (book) {
  if (book.playbook) {
    PJC.playbook = book.playbook;
  }
  if (book.actions) {
    PJC.actions = book.actions;
  }
  if (book.sounds) {
    PJC.soundSprites = book.sounds;
  }

  if (book.playbookOrder) {
    PJC.playbookOrder = book.playbookOrder;
  }

  // Tell SDK where are double pages, the AI story teller will tell them togther without waiting for flip
  // e.g., [cover],[p1,p2], [p3,p4]
  PJC.twoPageMode = book.meta.two_page_mode || false;

  const actions = _.map(PJC.actions, (value, prop) => ({
    value,
    prop,
  }));

  //bind animation (each clip) and voice_input actions
  actions.forEach((item) => {
    if (item.value && item.value.type) {
      if (item.value.type == "animation") {
        let clipRx = [];
        item.value.data.clips.forEach((clip) => {
          let clip$ = new rxjs.Observable((subscriber) => {
            console.log("play " + item.prop + " " + clip);
            //Each clip has its own binding context, leave this undefined
            //if return a obj, use it to reset tween (restore to original status)
            let rtn = PJC.clips[clip].call(undefined, function () {
              subscriber.next(clip);
              subscriber.complete();
            });
            if (rtn) {
              if (rtn.length) {
                PJC.viewingTweens.push(...rtn);
              } else {
                PJC.viewingTweens.push(rtn);
              }
            }
          });
          clipRx.push(clip$);
        });
        PJC.actionClips[item.prop] = clipRx;
      }
    }
  });
  //Add sound clip
  const soundSprites = _.map(PJC.soundSprites, (value, prop) => ({
    value,
    prop,
  }));
  soundSprites.forEach((item) => {
    if (item.value && item.value.src) {
      PJC.addClip(item.prop, function (cb) {
        PJC.playSoundSprite(
          item.value.src,
          item.value.start,
          item.value.duration,
          cb
        );
      });
    }
  });

  //bind control
  if (PJC.nextButton) PJC.nextButton.on("mousedown", PJC.nextPage);
  if (PJC.prevButton) PJC.prevButton.on("mousedown", PJC.prevPage);

  // listen to react native -> webview messages
  // partition into asr and control streams
  const source$ = rxjs
    .fromEvent(window, "message")
    .pipe(
          rxjs.operators.tap((event) => console.log("Raw event:", event.data)),
          rxjs.operators.map((event) => JSON.parse(PJC.atou(event.data))),
          rxjs.operators.tap((parsedData) => console.log("Parsed data:", parsedData)) // Log the parsed data
    );

  // seperate messages by topics
  const [asr$, temp$] = source$.pipe(
    rxjs.operators.partition((obj) => obj.topic == PJC.constants.GET_ASR_RESULT)
  );

  const [wt$, temp2$] = temp$.pipe(
    rxjs.operators.partition((obj) => obj.topic == PJC.constants.PRESS_WT)
  );

  const [wtr$, temp3$] = temp2$.pipe(
    rxjs.operators.partition((obj) => obj.topic == PJC.constants.RELEASE_WT)
  );

  const [ttsf$, temp4$] = temp3$.pipe(
    rxjs.operators.partition((obj) => obj.topic == PJC.constants.TTS_READ_END)
  );

  const [readf$, other$] = temp4$.pipe(
    rxjs.operators.partition((obj) => obj.topic == PJC.constants.READ_END)
  );

  PJC.asrStream$ = asr$;
  PJC.wt$ = wt$;
  PJC.wtr$ = wtr$;
  PJC.ttsf$ = ttsf$;
  PJC.readf$ = readf$;
  PJC.commandStream$ = other$;

  PJC.commandStream$.subscribe((obj) => {
    if (obj.topic == PJC.constants.NEXT_PAGE) {
      PJC.nextPage();
    } else if (obj.topic == PJC.constants.PREV_PAGE) {
      PJC.prevPage();
    }
  });
};

//connect pages, actions, clips as what playbook instructed
PJC.init = function (book, cb) {
  //allow change playbook with a json
  let urlParams = new URLSearchParams(window.location.search);
  let playbook = urlParams.get("playbook") || PJC.config.default_playbook; //The playbook's json file
  let mode = urlParams.get("mode") || PJC.config.default_mode; //auto play or interactive play
  let language = urlParams.get("language") || PJC.config.default_language; //e.g., en_us, es_es
  let customPlaybook = urlParams.get("custom_playbook");

  if (window.ReactNativeWebView) {
    // hide page control button (use native player's control instead).
    if (PJC.nextButton) PJC.nextButton.visible = false;
    if (PJC.prevButton) PJC.prevButton.visible = false;
  }

  const playbookUrl = customPlaybook
    ? customPlaybook
    : `./playbooks/${language}/${playbook}.json`;

  fetch(playbookUrl)
    .then((response) => response.json())
    .then((data) => {
      console.log("Load default playbook");
      const bookData = PJC.adaptor.playBookTransform(data);
      PJC.loadBook(bookData);
      cb();
    })
    .catch((error) => {
      console.error(error);
      console.log("No default playbook or load error, use built-in PJC.book");
      PJC.loadBook(book);
      cb();
    });

  if (mode == "wt") {
    console.log("Set action mode to walkie talkie");
    PJC.mode = "wt";
  } else {
    console.log("using default action mode");
  }
};

PJC.start = function (book, page) {
  if (PJC.config.auto_start) {
    setTimeout(function () {
      // Important. It has to be initialized first before play and after excuting animation definiations
      PJC.init(book, function () {
        PJC.fsm.play(page);
      });
    }, PJC.config.start_delay);
  }
};
// Above SDK will eventually go to a seperate JS. User only load config, playbook, actions ...
