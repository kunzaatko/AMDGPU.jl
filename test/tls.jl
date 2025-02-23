function async_tls(f=()->nothing; init=false)
    pre_tls = Ref{AMDGPU.TaskLocalState}()
    post_tls = Ref{AMDGPU.TaskLocalState}()
    wait(@async begin
        if init
            pre_tls[] = copy(AMDGPU.task_local_state())
        end
        f()
        post_tls[] = copy(AMDGPU.task_local_state())
    end)
    if init
        return pre_tls[], post_tls[]
    else
        return post_tls[]
    end
end

@testset "Basics" begin
    device = @inferred AMDGPU.device()
    @test device isa ROCDevice
    @test device === AMDGPU.Runtime.get_default_device()

    context = @inferred AMDGPU.context()
    @test context isa HIPContext
    @test AMDGPU.device_id(AMDGPU.device(context)) == AMDGPU.device_id(device)

    queue = @inferred AMDGPU.queue()
    @test queue isa ROCQueue

    stream = @inferred AMDGPU.stream()
    @test stream isa HIPStream
    @test AMDGPU.device_id(AMDGPU.device(context)) == AMDGPU.device_id(device)

    tls = @inferred AMDGPU.task_local_state()
    @test tls isa AMDGPU.TaskLocalState
    @test device === tls.device
    @test queue === tls.queue
    @test queue.priority == tls.priority
    @test stream === tls.stream
    @test stream.priority == tls.priority
    @test context === tls.context
end

if length(AMDGPU.devices()) > 1
@testset "Devices" begin
    dev1 = AMDGPU.devices()[1]
    tls1 = copy(AMDGPU.task_local_state())
    @assert tls1.device === dev1
    dev2 = AMDGPU.devices()[2]
    AMDGPU.device!(dev2)
    tls2 = copy(AMDGPU.task_local_state())
    AMDGPU.device!(dev1)
    tls3 = copy(AMDGPU.task_local_state())

    @test tls2.device === dev2
    @test tls1.device !== tls2.device
    @test tls1.context !== tls2.context
    @test tls2.queue isa ROCQueue
    @test tls1.queue !== tls2.queue
    @test tls2.stream isa HIPStream
    @test tls1.stream !== tls2.stream
    @test AMDGPU.device(tls2.queue) == dev2
    @test AMDGPU.device_id(AMDGPU.device(tls2.context)) == 2
    @test AMDGPU.device_id(AMDGPU.device(tls2.stream)) == 2

    @test tls3.device === dev1
    @test tls1.device === tls3.device
    @test tls1.context === tls3.context
    @test tls3.queue isa ROCQueue
    @test tls1.queue === tls3.queue
    @test tls2.stream isa HIPStream
    @test tls1.stream === tls3.stream
    @test AMDGPU.device(tls3.queue) == dev1
    @test AMDGPU.device_id(AMDGPU.device(tls3.context)) == 1
    @test AMDGPU.device_id(AMDGPU.device(tls3.stream)) == 1
end
else
@test_skip "Devices"
end

@testset "Queues/Streams" begin
    tls1 = copy(AMDGPU.task_local_state())
    queue1 = AMDGPU.queue()
    @test tls1.queue === queue1 === AMDGPU.queue()
    stream1 = AMDGPU.stream()
    @test tls1.stream === stream1 === AMDGPU.stream()
    @test tls1.priority == queue1.priority == stream1.priority == :normal

    tls2 = async_tls()
    @test tls2.device === tls1.device
    @test tls2.context === tls1.context
    @test tls2.queue !== tls1.queue
    @test tls2.stream !== tls1.stream
    @test tls2.priority == :normal

    tls3 = copy(AMDGPU.task_local_state())
    @test tls3.queue === queue1 === AMDGPU.queue()
    @test tls3.stream === stream1 === AMDGPU.stream()

    @testset "Priorities" begin
        AMDGPU.priority!(:high)
        tlsh = copy(AMDGPU.task_local_state())
        @test tlsh.priority == :high
        @test tlsh.queue !== tls1.queue
        @test tlsh.queue.priority == :high
        @test tlsh.stream !== tls1.stream
        @test tlsh.stream.priority == :high

        AMDGPU.priority!(:low)
        tlsl = copy(AMDGPU.task_local_state())
        @test tlsl.priority == :low
        @test tlsl.queue !== tls1.queue
        @test tlsl.queue.priority == :low
        @test tlsl.stream !== tls1.stream
        @test tlsl.stream.priority == :low

        AMDGPU.priority!(:normal)
        tlsn = copy(AMDGPU.task_local_state())
        @test tlsn.priority == :normal
        @test tlsn.queue.priority == :normal
        @test tlsn.stream.priority == :normal

        AMDGPU.priority!(:high)
        tlsn2 = async_tls()
        @test tlsn2.priority == :normal
        @test tlsn2.queue.priority == :normal
        @test tlsn2.stream.priority == :normal

        AMDGPU.priority!(:normal)
        tlsh2 = async_tls(init=false) do
            AMDGPU.priority!(:high)
        end
        @test tlsh2.priority == :high
        @test tlsh2.queue.priority == :high
        @test tlsh2.stream.priority == :high
        @test AMDGPU.task_local_state().priority == :normal
    end
end

function async_tls_lib(f=()->nothing; lib::Symbol)
    tls = Ref{Any}()
    wait(@async begin
        f()
        tls[] = task_local_storage(lib)
    end)
    return tls[]
end

if AMDGPU.functional(:rocblas)
    @testset "rocBLAS" begin
        handle = AMDGPU.rocBLAS.handle()
        @test handle isa AMDGPU.rocBLAS.rocblas_handle

        # FIXME: Switch context/stream, check handle differs
    end
else
    @test_skip "rocBLAS"
end
if AMDGPU.functional(:rocrand)
end
if AMDGPU.functional(:rocfft)
end
if AMDGPU.functional(:MIOpen)
end
