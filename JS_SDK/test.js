// Import the PJC module
const PJC = require('./pjc_sdk');

describe("PJC Unit Tests with Sample Playbook", () => {
  const samplePlaybook = {
    meta: {
      book_id: "8e28a441-7be5-40b0-a9b5-f207a8977197",
      book_name: "The Three Little Pigs",
      language: "en-US",
      age_group: "4+",
      voice_engine: "native",
      default_mode: "interactive",
    },
    playbookOrder: [
      "cover",
      "p1",
      "p2",
      "p3",
      "p4",
      "p5",
      "p6",
      "p7",
      "p8",
      "p9",
      "p10",
      "p11",
      "p12",
      "p13",
      "p14",
      "p15",
      "p16",
      "p17",
      "p18",
      "p19",
      "p20",
    ],
    playbook: {
      cover: [],
      p1: ["P1A1"],
      p2: ["P2A1"],
      p3: ["P3A1"],
    },
    actions: {
      P1A1: {
        type: "read",
        data: {
          text: "Once upon a time there was an old mother pig",
          type: "file",
          id: "f71e3275-9e3d-5a52-bfcc-89108e7bec33",
        },
      },
      P2A1: {
        type: "read",
        data: {
          text: "who had three little pigs",
          type: "file",
          id: "db4ad9f9-8e5f-58e9-bf36-91abca7ad80c",
        },
      },
      P3A1: {
        type: "read",
        data: {
          text: "and not enough food to feed them.",
          type: "file",
          id: "e6d75bda-facf-510c-b111-177dad2dcaf7",
        },
      },
    },
    sounds: {},
  };

  beforeEach(() => {
    // Reset PJC context before each test
    PJC.context = {
      started: false,
      currentPage: "cover",
      log: [],
      currentActions: [],
      actionIndex: 0,
    };
    PJC.playbook = {};
    PJC.actions = {};
  });

  test("Should load the sample playbook correctly", () => {
    PJC.loadBook(samplePlaybook);

    expect(PJC.playbook).toEqual(samplePlaybook.playbook);
    expect(PJC.actions).toEqual(samplePlaybook.actions);
    expect(PJC.context.currentPage).toBe("cover");
  });

  test("Should handle a page with no actions (cover page)", () => {
    PJC.loadBook(samplePlaybook);

    const finishPageSpy = jest.spyOn(PJC.fsm, "finishPage");

    PJC.fsm.play("cover");

    expect(finishPageSpy).toHaveBeenCalled();
    finishPageSpy.mockRestore();
  });

  test("Should execute a single action on page p1", async () => {
    PJC.loadBook(samplePlaybook);

    const playSpy = jest.spyOn(PJC, "playAction").mockImplementation((action) =>
      Promise.resolve()
    );

    await new Promise((resolve) => {
      PJC.fsm.play("p1");
      setTimeout(resolve, PJC.config.actionGap * 2);
    });

    expect(playSpy).toHaveBeenCalledTimes(1);
    expect(PJC.context.currentPage).toBe("p1");
    expect(PJC.context.actionIndex).toBe(1);
    playSpy.mockRestore();
  });

  test("Should transition through all actions on page p2", async () => {
    PJC.loadBook(samplePlaybook);

    const playSpy = jest.spyOn(PJC, "playAction").mockImplementation((action) =>
      Promise.resolve()
    );

    await new Promise((resolve) => {
      PJC.fsm.play("p2");
      setTimeout(resolve, PJC.config.actionGap * 2);
    });

    expect(playSpy).toHaveBeenCalledTimes(1);
    expect(PJC.context.currentPage).toBe("p2");
    expect(PJC.context.actionIndex).toBe(1);
    playSpy.mockRestore();
  });

  test("Should finish book interaction on last page", async () => {
    PJC.loadBook(samplePlaybook);

    const finishSpy = jest.spyOn(PJC.fsm, "finish");

    await new Promise((resolve) => {
      PJC.fsm.play("p20");
      setTimeout(() => {
        PJC.fsm.finish();
        resolve();
      }, PJC.config.actionGap);
    });

    expect(finishSpy).toHaveBeenCalled();
    finishSpy.mockRestore();
  });

  test("Should correctly handle invalid action types", async () => {
    const invalidPlaybook = {
      ...samplePlaybook,
      playbook: {
        ...samplePlaybook.playbook,
        p4: ["InvalidAction"],
      },
    };

    PJC.loadBook(invalidPlaybook);

    const playSpy = jest.spyOn(PJC, "playAction").mockImplementation(() =>
      Promise.resolve()
    );

    await new Promise((resolve) => {
      PJC.fsm.play("p4");
      setTimeout(resolve, PJC.config.actionGap * 2);
    });

    expect(playSpy).not.toHaveBeenCalled();
    expect(console.error).toHaveBeenCalledWith("Invalid action key:", "InvalidAction");
    playSpy.mockRestore();
  });
});