this.PJC = this.PJC || {}; // Global namespace for SDK

(function () {
    "use strict";
    
    PJC.constants = {
        NEXT_PAGE: "next_page",
        PREV_PAGE: "prev_page",
    };
    
    // Utility functions for Base64 encoding and decoding with URL encoding
    PJC.utoa = function (data) {
        try {
            return btoa(encodeURIComponent(data)); // Encode to Base64 with URL encoding
        } catch (error) {
            console.error("Error in utoa:", error);
            return null;
        }
    };
    
    PJC.atou = function (base64) {
        try {
            return decodeURIComponent(atob(base64)); // Decode Base64 and URL decode
        } catch (error) {
            console.error("Error in atou:", error);
            return null;
        }
    };
    
    // Function to process React Native -> WebView messages
    const source$ = rxjs
    .fromEvent(window, "message")
    .pipe(
          rxjs.operators.tap((event) => console.log("Raw event data:", event.data)),
          rxjs.operators.map((event) => {
              try {
                  return JSON.parse(PJC.atou(event.data)); // Decode and parse data
              } catch (error) {
                  console.error("Failed to parse incoming message:", error);
                  return null;
              }
          }),
          rxjs.operators.filter((parsedData) => parsedData !== null), // Filter out invalid messages
          rxjs.operators.tap((parsedData) =>
                             console.log("Parsed data:", parsedData)
                             ) // Log the parsed data
          );
    
    // Assign the command stream to PJC for external use
    PJC.commandStream$ = source$;
    
    // Subscribe to the command stream
    PJC.commandStream$.subscribe({
        next: (obj) => {
            if (obj.topic === PJC.constants.NEXT_PAGE) {
                console.log("Navigating to the next page...");
                PJC.nextPage?.();
            } else if (obj.topic === PJC.constants.PREV_PAGE) {
                console.log("Navigating to the previous page...");
                PJC.prevPage?.();
            } else {
                console.warn("Unknown topic:", obj.topic);
            }
        },
        error: (error) => console.error("Command stream error:", error),
        complete: () => console.log("Command stream completed."),
    });
})();
