// Define a global namespace for the SDK
this.PJC = this.PJC || {};

(function () {
  "use strict";

  const PJC = (this.PJC = this.PJC || {});

  // Constants
  PJC.constants = {
    BOOK_START: "book_start",
    BOOK_END: "book_end",
    PAGE_CHANGE: "page_change",
    USER_START: "user_start",
    PAGE_READY: "page_ready",
    PAGE_PLAY: "page_play",
    NEXT_PAGE: "next_page",
    PREV_PAGE: "prev_page",
  };

  PJC.actionNames = {
    READ: "read",
    AGENT: "agent",
  };

  // Initial Configuration
  PJC.config = {
    autoStart: true,
    pageFlip: "manual",
    pageWait: 3000,
    startDelay: 1000,
    actionGap: 1000,
    defaultPlaybook: "default",
    defaultLanguage: "en-US",
    defaultMode: "conv",
  };

  // Context and State
  PJC.context = {
    started: false,
    currentPage: "cover",
    log: [],
    currentActions: [],
    actionIndex: 0,
  };

  // Initialize FSM
  PJC.fsm = new StateMachine({
    init: "start",
    transitions: [
      { name: "play", from: "start", to: "pageReady" },
      { name: "startAction", from: "pageReady", to: "play" },
      { name: "completeAction", from: "play", to: "action" },
      { name: "nextAction", from: "action", to: "play" },
      { name: "finishPage", from: "action", to: "pageReady" },
      { name: "finish", from: "pageReady", to: "finish" },
    ],
    methods: {
      onPlay: (lifecycle, page) => {
        console.log("Playing page:", page);
        PJC.context.currentPage = page;
        PJC.context.currentActions = PJC.playbook[page] || [];
        PJC.context.actionIndex = 0;

        if (PJC.context.currentActions.length > 0) {
          PJC.fsm.startAction();
        } else {
          console.log("No actions on the page. Moving to pageReady.");
          PJC.fsm.finishPage();
        }
      },
      onStartAction: () => {
        console.log("Starting action:", PJC.context.actionIndex);
        const actionKey =
          PJC.context.currentActions[PJC.context.actionIndex];
        const action = PJC.actions[actionKey];

        if (action) {
          PJC.playAction(action).then(() => {
            PJC.fsm.completeAction();
          });
        } else {
          console.error("Invalid action key:", actionKey);
          PJC.fsm.completeAction();
        }
      },
      onCompleteAction: () => {
        console.log("Completed action:", PJC.context.actionIndex);
        if (
          PJC.context.actionIndex < PJC.context.currentActions.length - 1
        ) {
          PJC.context.actionIndex++;
          PJC.fsm.nextAction();
        } else {
          console.log("All actions for the page are complete.");
          PJC.fsm.finishPage();
        }
      },
      onFinishPage: () => {
        console.log("Page completed. Returning to pageReady.");
        const currentIndex = PJC.playbookOrder.indexOf(
          PJC.context.currentPage
        );
        PJC.talkToNative(PJC.constants.PAGE_READY, {
          current: currentIndex,
          total: PJC.playbookOrder.length,
        });
      },
      onFinish: () => {
        console.log("Book interaction finished.");
        PJC.talkToNative(PJC.constants.BOOK_END);
      },
    },
  });

  // Play Actions
  PJC.playAction = (action) => {
    return new Promise((resolve) => {
      console.log("Playing action:", action);
      setTimeout(resolve, PJC.config.actionGap);
    });
  };

  // Communication with Native
  PJC.talkToNative = (topic, data) => {
    console.log("Talking to native:", { topic, data });
  };

  // Load Book
  PJC.loadBook = (book) => {
    PJC.playbook = book.playbook || {};
    PJC.actions = book.actions || {};
    PJC.playbookOrder = book.playbookOrder || [];
    PJC.context.currentPage = PJC.playbookOrder[0] || "cover";

    console.log("Playbook loaded:", PJC.playbook);
  };

  // For Node.js testing environment
  if (typeof module !== "undefined" && module.exports) {
    module.exports = PJC;
  }
})();
