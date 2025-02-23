@testset "ROCDeviceArray" begin
    RA = ROCArray(rand(4,4))
    RD = rocconvert(RA)
    @test RD isa AMDGPU.Device.ROCDeviceMatrix

    # Host indexing is disallowed
    @test_throws Exception RD[1]
    @test_throws Exception RD[1,1]
    RD_view = @view RD[2:3, 2:3]
    @test RD_view isa SubArray
    @test_throws Exception RD_view[1]
    @test_throws Exception RD_view[1,1]
    RD_adj = RD'
    @test RD_adj isa LinearAlgebra.Adjoint
    @test_throws Exception RD_adj[1]
    @test_throws Exception RD_adj[1,1]

    # Custom show methods are defined
    @test occursin("4×4 device array at", sprint(io->show(io, RD)))
    @test occursin("2×2 device array view", sprint(io->show(io, RD_view)))
    @test occursin("4×4 device array wrapper Adjoint", sprint(io->show(io, RD_adj)))

    # Custom hash methods are defined
    @test AMDGPU.Runtime.khash(RD) isa UInt # test that hashing doesn't segfault
    @test AMDGPU.Runtime.khash(RD_view) isa UInt # test that SubArray hashing works
end
