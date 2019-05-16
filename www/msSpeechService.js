const exec = require('cordova/exec');

exports.recognizeOnce = function recognizeOnce(onResponse, onError) {
  exec(onResponse, onError, 'MicrosoftSpeechService', 'recognizeOnce', []);
};

exports.startContinuousRecognition = function startContinuousRecognition(onResponse, onError) {
  exec(onResponse, onError, 'MicrosoftSpeechService', 'startContinuousRecognition', []);
};

exports.stopContinuousRecognition = function stopContinuousRecognition(onResponse, onError) {
  exec(onResponse, onError, 'MicrosoftSpeechService', 'stopContinuousRecognition', []);
};
