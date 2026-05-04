#ifndef LlamaBridge_h
#define LlamaBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Token callback. Return NO to stop generation cooperatively.
typedef BOOL (^LBTokenCallback)(NSString *token);

@interface LBSamplingParams : NSObject
@property (nonatomic) float temperature;       // default 0.2 (translation = low temperature)
@property (nonatomic) float topP;              // default 0.9
@property (nonatomic) NSInteger topK;          // default 40
@property (nonatomic) NSInteger maxNewTokens;  // default 512
@property (nonatomic) NSInteger seed;          // -1 for random
@end

/// Thin Objective-C++ wrapper around llama.cpp. One instance == one loaded model.
@interface LlamaBridge : NSObject

/// Load a GGUF model. Heavy: call off the main thread.
/// @param contextSize n_ctx; recommend 2048 for translation.
/// @param nThreads CPU threads for prompt eval; pass 0 for auto.
/// @param useMetal enable GGML Metal backend (Apple Silicon only).
- (nullable instancetype)initWithModelPath:(NSString *)path
                               contextSize:(NSInteger)contextSize
                                  nThreads:(NSInteger)nThreads
                                  useMetal:(BOOL)useMetal
                                     error:(NSError **)error;

/// Generate text from a fully-formatted prompt. Streams tokens via callback.
/// Returns the concatenated output string, or `nil` on failure (which makes
/// the method bridge to a Swift `throws` function).
/// Safe to call from a background queue. Calling -cancel on another thread
/// sets an atomic stop flag.
- (nullable NSString *)generateWithPrompt:(NSString *)prompt
                                   params:(LBSamplingParams *)params
                                  onToken:(nullable LBTokenCallback)onToken
                                    error:(NSError **)error;

- (void)cancel;

/// Decoded performance counters from the last generation.
@property (nonatomic, readonly) double lastTokensPerSecond;
@property (nonatomic, readonly) NSInteger lastTokenCount;

@end

NS_ASSUME_NONNULL_END

#endif /* LlamaBridge_h */
