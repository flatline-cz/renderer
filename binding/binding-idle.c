//
// Created by tumap on 12/6/22.
//
#include "binding-idle.h"
#include <trace.h>

#ifdef PIC32
#include "memcpy.h"
#else

#include <string.h>

#endif


#define MAX_IDLE_ROUTINES           32

typedef struct tagIdleRoutineContext {
    // scheduling
    tTime time_offset;
    tTime period;
    tTime scheduled_invocation;

    // routine
    rRendererIdleRoutine routine;
    void *routine_arg;

} tIdleRoutineContext;

static tIdleRoutineContext contexts[MAX_IDLE_ROUTINES];
static unsigned context_count;
static unsigned next_context;

static int find_routine(rRendererIdleRoutine routine, void *routine_arg);

static void find_nearest_context();


void binding_idle_init() {
    context_count = 0;
    next_context = 0;
}


bool binding_idle_handle() {
    // no contexts registered?
    if (!context_count)
        return false;

    // context not valid?
    if (next_context >= context_count) {
        find_nearest_context();
        // not found?
        if (next_context >= context_count)
            return false;
    }

    // check scheduler invocation time
    if (contexts[next_context].scheduled_invocation > TIME_GET)
        return false;

    // execute routine
    tIdleRoutineContext *ctx = contexts + next_context;
    ctx->routine(TIME_GET - ctx->time_offset, ctx->routine_arg);

    // schedule next invocation
    ctx->scheduled_invocation = TIME_GET + ctx->period;

    // find next context
    find_nearest_context();

    return true;
}

void binding_idle_register(tTime period, rRendererIdleRoutine routine, void *routine_arg) {
    // sanity check
    if (period < 10) {
        TRACE("IDLE-BINDING: invalid params (short period)")
#ifdef PIC32
        return;
#else
        abort();
#endif
    }
    if (!routine) {
        TRACE("IDLE-BINDING: invalid params (missing routine)")
#ifdef PIC32
        return;
#else
        abort();
#endif
    }

    // routine already exists?
    int index = find_routine(routine, routine_arg);
    tIdleRoutineContext *ctx = (index >= 0) ? (contexts + index) : 0;
    if (ctx) {
        int32_t delta = (int32_t) period - (int32_t) ctx->period;
        ctx->period = period;
        ctx->scheduled_invocation += delta;
    } else {
        // error handling
        if (context_count + 1 > MAX_IDLE_ROUTINES) {
            TRACE("IDLE-BINDING: Too many routines")
#ifdef PIC32
            return;
#else
            abort();
#endif
        }
        ctx = contexts + context_count;
        context_count++;
        ctx->period = period;
        ctx->scheduled_invocation = TIME_GET + period;
        ctx->routine = routine;
        ctx->routine_arg = routine_arg;
        ctx->time_offset = TIME_GET;
    }

    find_nearest_context();
}

void binding_idle_deregister(rRendererIdleRoutine routine, void *routine_arg) {
    int index = find_routine(routine, routine_arg);
    if (index < 0)
        return;

    if (index + 1 < context_count)
        memcpy(contexts + index, contexts + index + 1, context_count - index - 1);
    context_count--;

    find_nearest_context();
}

static void find_nearest_context() {
    unsigned min_index = context_count, i;
    tTime min_time;

    for (i = 0; i < context_count; i++) {
        if (min_index == context_count || contexts[i].scheduled_invocation < min_time) {
            min_time = contexts[i].scheduled_invocation;
            min_index = i;
        }
    }

    next_context = min_index;
}

static int find_routine(rRendererIdleRoutine routine, void *routine_arg) {
    unsigned i;
    for (i = 0; i < context_count; i++) {
        if (contexts[i].routine == routine && contexts[i].routine_arg == routine_arg)
            return (int) i;
    }
    return -1;
}
