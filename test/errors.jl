using Enzyme, Test


@testset "Method errors" begin
     fwd = Enzyme.autodiff_thunk(Forward, Const{typeof(sum)}, Duplicated, Duplicated{Vector{Float64}})
     @test_throws MethodError fwd(ones(10))
     @test_throws MethodError fwd(Duplicated(ones(10), ones(10)))
     @test_throws MethodError fwd(Const(first), Duplicated(ones(10), ones(10)))
     # TODO
     # @test_throws MethodError fwd(Const(sum), Const(ones(10)))
     fwd(Const(sum), Duplicated(ones(10), ones(10)))
end

@testset "Mismatched return" begin
    @test_throws ErrorException autodiff(Reverse, _->missing, Active, Active(2.1))
    @test_throws ErrorException autodiff_deferred(Reverse, Const(_->missing), Active, Active(2.1))
end

@testset "UndefVar" begin
    function f_undef(x, y)
        if x
            undefinedfnthowmagic()
        end
        y
    end
    @test 1.0 ≈ autodiff(Reverse, f_undef, Const(false), Active(2.14))[1][2]
    @test_throws Base.UndefVarError autodiff(Reverse, f_undef, Const(true), Active(2.14))

    @test 1.0 ≈ autodiff(Forward, f_undef, Const(false), Duplicated(2.14, 1.0))[1]
    @test_throws Base.UndefVarError autodiff(Forward, f_undef, Const(true), Duplicated(2.14, 1.0))
end

@testset "Exception" begin

    f_no_derv(x) = ccall("extern doesnotexist", llvmcall, Float64, (Float64,), x)
    @test_throws Enzyme.Compiler.EnzymeNoDerivativeError autodiff(Reverse, f_no_derv, Active, Active(0.5))

    f_union(cond, x) = cond ? x : 0
    g_union(cond, x) = f_union(cond,x)*x
    if sizeof(Int) == sizeof(Int64)
        @test_throws Enzyme.Compiler.IllegalTypeAnalysisException autodiff(Reverse, g_union, Active, Const(true), Active(1.0))
    else
        @test_throws Enzyme.Compiler.IllegalTypeAnalysisException autodiff(Reverse, g_union, Active, Const(true), Active(1.0f0))
    end
    # TODO: Add test for NoShadowException
end
 
@testset "Nested Type Error" begin
    nested_f(x) = sum(tanh, x)

    function nested_df!(dx, x)
        make_zero!(dx)
        autodiff_deferred(Reverse, Const(nested_f), Active, Duplicated(x, dx))
        return nothing
    end

    function nested_hvp!(hv, v, x)
        make_zero!(hv)
        autodiff(Forward, nested_df!, Const, Duplicated(make_zero(x), hv), Duplicated(x, v))
        return nothing
    end

    x = [0.5]

    # primal: sanity check
    @test nested_f(x) ≈ sum(tanh, x)

    # gradient: works
    dx = make_zero(x)
    nested_df!(dx, x)

    @test dx ≈ (sech.(x).^2)

    v = first(onehot(x))
    hv = make_zero(v)
    nested_hvp!(hv, v, x)
end


