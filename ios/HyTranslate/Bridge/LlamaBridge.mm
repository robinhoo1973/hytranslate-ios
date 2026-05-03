#import "LlamaBridge.h"
#import <atomic>
#import <vector>
#import <string>
#import <chrono>

// llama.cpp public C API (provided via SwiftPM `llama` product).
#import <llama/llama.h>

@implementation LBSamplingParams
- (instancetype)init {
    if ((self = [super init])) {
        _temperature  = 0.2f;
        _topP         = 0.9f;
        _topK         = 40;
        _maxNewTokens = 512;
        _seed         = -1;
    }
    return self;
}
@end

@implementation LlamaBridge {
    llama_model    *_model;
    llama_context  *_ctx;
    const llama_vocab *_vocab;
    std::atomic<bool> _stopFlag;
    double _lastTps;
    NSInteger _lastTokens;
}

+ (void)initialize {
    if (self == [LlamaBridge class]) {
        llama_backend_init();
    }
}

- (nullable instancetype)initWithModelPath:(NSString *)path
                               contextSize:(NSInteger)contextSize
                                  nThreads:(NSInteger)nThreads
                                  useMetal:(BOOL)useMetal
                                     error:(NSError **)error {
    if (!(self = [super init])) return nil;

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = useMetal ? 999 : 0;   // offload everything to Metal when available
    mparams.use_mmap     = true;                  // critical for low-RAM devices
    mparams.use_mlock    = false;

    _model = llama_model_load_from_file(path.UTF8String, mparams);
    if (!_model) {
        if (error) *error = [NSError errorWithDomain:@"LlamaBridge" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Failed to load GGUF model"}];
        return nil;
    }
    _vocab = llama_model_get_vocab(_model);

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx     = (uint32_t)contextSize;
    cparams.n_batch   = 512;
    cparams.n_threads = (int32_t)(nThreads > 0 ? nThreads : 4);
    cparams.n_threads_batch = cparams.n_threads;

    _ctx = llama_init_from_model(_model, cparams);
    if (!_ctx) {
        llama_model_free(_model);
        _model = nullptr;
        if (error) *error = [NSError errorWithDomain:@"LlamaBridge" code:2
            userInfo:@{NSLocalizedDescriptionKey: @"Failed to create llama_context"}];
        return nil;
    }

    _stopFlag.store(false);
    return self;
}

- (void)dealloc {
    if (_ctx)   llama_free(_ctx);
    if (_model) llama_model_free(_model);
}

- (void)cancel { _stopFlag.store(true); }

- (NSString *)generateWithPrompt:(NSString *)prompt
                          params:(LBSamplingParams *)params
                         onToken:(LBTokenCallback)onToken
                           error:(NSError **)error {
    _stopFlag.store(false);
    _lastTps = 0; _lastTokens = 0;

    // ---- Tokenize prompt ---------------------------------------------------
    const char *cstr = prompt.UTF8String;
    int32_t plen = (int32_t)strlen(cstr);
    int32_t cap = plen + 16;
    std::vector<llama_token> tokens(cap);
    int32_t n = llama_tokenize(_vocab, cstr, plen, tokens.data(), cap,
                               /*add_special*/ true, /*parse_special*/ true);
    if (n < 0) {
        tokens.resize(-n);
        n = llama_tokenize(_vocab, cstr, plen, tokens.data(), -n, true, true);
    }
    tokens.resize(n);

    // ---- Build sampler chain ---------------------------------------------
    llama_sampler_chain_params sp = llama_sampler_chain_default_params();
    llama_sampler *smpl = llama_sampler_chain_init(sp);
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k((int32_t)params.topK));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(params.topP, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(params.temperature));
    uint32_t seed = params.seed < 0 ? LLAMA_DEFAULT_SEED : (uint32_t)params.seed;
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(seed));

    // ---- Decode prompt in batches ----------------------------------------
    llama_memory_clear(llama_get_memory(_ctx), true);

    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t)tokens.size());
    if (llama_decode(_ctx, batch) != 0) {
        llama_sampler_free(smpl);
        if (error) *error = [NSError errorWithDomain:@"LlamaBridge" code:3
            userInfo:@{NSLocalizedDescriptionKey: @"llama_decode (prompt) failed"}];
        return @"";
    }

    // ---- Sampling loop ---------------------------------------------------
    NSMutableString *result = [NSMutableString string];
    auto tStart = std::chrono::steady_clock::now();
    int generated = 0;
    char piece[256];

    for (int i = 0; i < params.maxNewTokens; ++i) {
        if (_stopFlag.load()) break;

        llama_token id = llama_sampler_sample(smpl, _ctx, -1);
        if (llama_vocab_is_eog(_vocab, id)) break;

        int32_t plen2 = llama_token_to_piece(_vocab, id, piece, sizeof(piece), 0, true);
        if (plen2 > 0) {
            NSString *tok = [[NSString alloc] initWithBytes:piece length:plen2 encoding:NSUTF8StringEncoding];
            if (tok) {
                [result appendString:tok];
                if (onToken && !onToken(tok)) break;
            }
        }
        ++generated;

        llama_batch nb = llama_batch_get_one(&id, 1);
        if (llama_decode(_ctx, nb) != 0) break;
    }

    auto tEnd = std::chrono::steady_clock::now();
    double secs = std::chrono::duration<double>(tEnd - tStart).count();
    _lastTokens = generated;
    _lastTps = secs > 0 ? generated / secs : 0;

    llama_sampler_free(smpl);
    return result;
}

- (double)lastTokensPerSecond { return _lastTps; }
- (NSInteger)lastTokenCount   { return _lastTokens; }

@end
