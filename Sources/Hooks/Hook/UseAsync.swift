@discardableResult
public func useAsync<Output>(
    _ updateStrategy: HookUpdateStrategy,
    _ operation: @escaping () async -> Output
) -> AsyncPhase<Output, Never> {
    useHook(
        AsyncHook(
            updateStrategy: updateStrategy,
            operation: operation
        )
    )
}

@discardableResult
public func useAsync<Output>(
    _ updateStrategy: HookUpdateStrategy,
    _ operation: @escaping () async throws -> Output
) -> AsyncPhase<Output, Error> {
    useHook(
        AsyncThrowingHook(
            updateStrategy: updateStrategy,
            operation: operation
        )
    )
}

internal struct AsyncHook<Output>: Hook {
    let updateStrategy: HookUpdateStrategy?
    let shouldDeferredCompute = true
    let operation: () async -> Output

    func makeState() -> State {
        State()
    }

    func value(coordinator: Coordinator) -> AsyncPhase<Output, Never> {
        coordinator.state.phase
    }

    func updateState(coordinator: Coordinator) {
        coordinator.state.task = Task { @MainActor in
            coordinator.state.phase = .running
            coordinator.updateView()

            let output = await operation()
            coordinator.state.phase = .success(output)
            coordinator.updateView()
        }
    }

    func dispose(state: State) async {
        state.task?.cancel()
        state.task = nil
    }
}

internal extension AsyncHook {
    final class State {
        var phase = AsyncPhase<Output, Never>.pending
        var task: Task<Void, Never>?
    }
}

internal struct AsyncThrowingHook<Output>: Hook {
    let updateStrategy: HookUpdateStrategy?
    let shouldDeferredCompute = true
    let operation: () async throws -> Output

    func makeState() -> State {
        State()
    }

    func value(coordinator: Coordinator) -> AsyncPhase<Output, Error> {
        coordinator.state.phase
    }

    func updateState(coordinator: Coordinator) {
        coordinator.state.task = Task { @MainActor in
            coordinator.state.phase = .running
            coordinator.updateView()

            do {
                let output = try await operation()
                coordinator.state.phase = .success(output)
            }
            catch {
                coordinator.state.phase = .failure(error)
            }

            coordinator.updateView()
        }
    }

    func dispose(state: State) async {
        state.task?.cancel()
        state.task = nil
    }
}

internal extension AsyncThrowingHook {
    final class State {
        var phase = AsyncPhase<Output, Error>.pending
        var task: Task<Void, Never>?
    }
}
