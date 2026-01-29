(function (window) {
  "use strict";

  window.FPW = window.FPW || {};
  window.FPW.DashboardState = {
    floatPlanState: {
      all: [],
      filtered: [],
      query: ""
    },
    vesselState: {
      all: []
    },
    contactState: {
      all: []
    },
    passengerState: {
      all: []
    },
    operatorState: {
      all: []
    },
    waypointState: {
      all: []
    },
    homePortLatLng: null
  };
})(window);
