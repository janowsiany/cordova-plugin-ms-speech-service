#import <Cordova/CDV.h>
#import <MicrosoftCognitiveServicesSpeech/SPXSpeechApi.h>

@interface MicrosoftSpeechService : CDVPlugin {
  Boolean isRecognitionInProgress;
  NSString* callback;

  SPXSpeechRecognizer* speechRecognizer;
}

- (void)recognizeOnce:(CDVInvokedUrlCommand*)command;
- (void)startContinuousRecognition:(CDVInvokedUrlCommand*)command;
- (void)stopContinuousRecognition:(CDVInvokedUrlCommand*)command;

@end

@implementation MicrosoftSpeechService

- (void)setupSpeechRecognizer {
  if (speechRecognizer) {
    NSLog(@"Speech recognizer already set up");
    return;
  }
    NSString* speechKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MicrosoftSpeechServiceSpeechKey"];
    NSString* serviceRegion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MicrosoftSpeechServiceServiceRegion"];

    SPXSpeechConfiguration *speechConfig = [[SPXSpeechConfiguration alloc] initWithSubscription:speechKey region:serviceRegion];
    if (!speechConfig) {
        NSAssert(false, @"Could not load speech config");
        return;
    }

    speechRecognizer = [[SPXSpeechRecognizer alloc] init:speechConfig];
    if (!speechRecognizer) {
        NSAssert(false, @"Could not create speech recognizer");
        return;
    }

    NSLog(@"Speech recognizer set up");
}

- (void)cleanUpRecognition {
  speechRecognizer = nil;
  isRecognitionInProgress = false;
}

- (void)recognizeOnce:(CDVInvokedUrlCommand*)command {
    [self setupSpeechRecognizer];

    if (isRecognitionInProgress) {
        NSLog(@"Recognition already in progress");
        [self sendRecognitionError:(@"Recognition already in progress")];
        return;
    }

    isRecognitionInProgress = true;
    callback = command.callbackId;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self recognizeOnce];
    });
}

- (void)startContinuousRecognition:(CDVInvokedUrlCommand*)command {
    [self setupSpeechRecognizer];

    if (isRecognitionInProgress) {
        NSLog(@"Recognition already in progress");
        [self sendRecognitionError:(@"Recognition already in progress")];
        return;
    }

    isRecognitionInProgress = true;
    callback = command.callbackId;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self startContinuousRecognition];
    });
}

- (void)stopContinuousRecognition:(CDVInvokedUrlCommand*)command {
    if (!isRecognitionInProgress) {
        NSLog(@"Recognition is not in progress");
        [self sendRecognitionError:(@"Recognition is not in progress")];
        return;
    }

    [self setupSpeechRecognizer];
    [speechRecognizer stopContinuousRecognition];
    [self cleanUpRecognition];
}

- (void)recognizeOnce {
    SPXSpeechRecognitionResult *speechResult = [speechRecognizer recognizeOnce];
    if (SPXResultReason_Canceled == speechResult.reason) {
        SPXCancellationDetails *details = [[SPXCancellationDetails alloc] initFromCanceledRecognitionResult:speechResult];
        NSLog(@"Speech recognition was canceled: %@. Did you pass the correct key/region combination?", details.errorDetails);
        [self sendRecognitionError:([NSString stringWithFormat:@"Canceled: %@", details.errorDetails ])];
    } else if (SPXResultReason_RecognizedSpeech == speechResult.reason) {
        NSLog(@"Speech recognition result received: %@", speechResult.text);
        [self sendRecognitionResult:(speechResult.text) isFinal:YES];
    } else {
        NSLog(@"There was an error.");
        [self sendRecognitionError:(@"Speech Recognition Error")];
    }

    [self cleanUpRecognition];
}

- (void)startContinuousRecognition {
    [speechRecognizer addRecognizingEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received intermediate result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        [self sendRecognitionResult:(eventArgs.result.text) isFinal:NO];
    }];

    [speechRecognizer addRecognizedEventHandler: ^ (SPXSpeechRecognizer *recognizer, SPXSpeechRecognitionEventArgs *eventArgs) {
        NSLog(@"Received final result event. SessionId: %@, recognition result:%@. Status %ld. offset %llu duration %llu resultid:%@", eventArgs.sessionId, eventArgs.result.text, (long)eventArgs.result.reason, eventArgs.result.offset, eventArgs.result.duration, eventArgs.result.resultId);
        [self sendRecognitionResult:(eventArgs.result.text) isFinal:YES];
        [speechRecognizer stopContinuousRecognition];
        isRecognitionInProgress = false;
    }];

    [speechRecognizer startContinuousRecognition];
}

- (void)sendRecognitionResult:(NSString *) recognitionResult isFinal:(Boolean) isFinal {
    NSDictionary* result = @{ @"value": recognitionResult, @"isFinal" : isFinal ? @YES : @NO };

    [self sendResponse:(result) withStatus:CDVCommandStatus_OK];
}

- (void)sendRecognitionError:(NSString *) recognitionError {
    NSDictionary* error = @{ @"message": recognitionError };

    [self sendResponse:(error) withStatus:CDVCommandStatus_ERROR];
}

- (void)sendResponse:(NSDictionary *) response withStatus:(CDVCommandStatus *) status {
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:status messageAsDictionary:response];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callback];
    }];
}

@end
