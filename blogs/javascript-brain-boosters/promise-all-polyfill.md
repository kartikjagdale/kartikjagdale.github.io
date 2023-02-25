---
permalink: /blogs/javascript-brain-boosters/promise-all-polyfill
layout: post
title: Promise.all polyfill
---

### Problem Statement

**TLDR:**: Implement a function which mimcks behaviour of `Promise.all()`

All Browsers don't support `Promise.all()` method, this can lead to compatibility issue and inconsistent behaviour across
different browsers. Hence we need to create a polyfill that can provide the same functionality as `Promise.all` for all browsers
that don't support it natively;

Task here is to create the polyfill that should be able to handle all of the features and functionality of Promise.all(),
including the ability to handle an array of promises and return a single promise that resolves when all of the promises
in the array have resolved, or rejects if any of the promises reject.

### Approach

To implement this we need to understand how `Promise.all` works, without going into too much discussion,
I drilled down the requirement for us below:

1. Should return all resolved results in promises in an array once all promises are completed;
2. If any one of it fails, it should cancel and directly return the error object;
3. By default, I checked this and if only resolve promise without any response, it returns array of undefined.

---

#### Implementation

```javascript
Promise.myAll = function (promises) {
  let completedPromises = promises.length;
  let results = new Array(promises.length).fill(undefined);

  return new Promise((resolve, reject) => {
    // if all the promises are completed, 
    // the checkIfDone will resolve and return the results
    let checkIfDone = () => {
      if (--completedPromises === 0) resolve(results);
    };

    promises.forEach((promise, index) => {
      promise
        .then((response) => {
          results[index] = response;
        })
        .catch((error) => {
          reject(error);
        })
        .then(checkIfDone);
    });
  });
};
```

#### Example Test -

```javascript
// Input:
function dummyPromise(time) {
  return new Promise(function (resolve, reject) {
    setTimeout(function () {
      resolve(time);
    }, time);
  });
}

const dummyTaskList = [
  dummyPromise(1000), 
  dummyPromise(2000), 
  dummyPromise(5000)
];

// Run Promise.myAll
Promise.myAll(dummyTaskList).then(
  (response) => {
    console.log(response);
  },
  (error) => console.log(error)
);

// Output:
// >> [ 1000, 2000, 5000 ]
```

#### Example Test using Promise which throws error -

```javascript
// Input:
// ... function dummyPromise ....;

function errorTask(time) {
  return new Promise(function (resolve, reject) {
    setTimeout(function () {
      reject(new Error("Error Occured"));
    }, time);
  });
};

const dummyTaskList = [
  dummyPromise(1000), 
  errorTask(2000), // A promise which will throw error;
  dummyPromise(5000)
];

// Run Promise.myAll
Promise.myAll(dummyTaskList).then(
  (response) => {
    console.log(response);
  },
  (error) => console.log(error);
);

// Output:
// >> Error: Error Occured
// at Timeout._onTimeout (/tmp/4P6KpVRaRD.js:13:14)
// at listOnTimeout (internal/timers.js:554:17)
// at processTimers (internal/timers.js:497:7)
```
