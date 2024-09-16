module EnzymeRules

import EnzymeCore
import EnzymeCore: Annotation, Const, Duplicated, Mode
export RevConfig, RevConfigWidth
export FwdConfig, FwdConfigWidth
export AugmentedReturn
export needs_primal, needs_shadow, width, overwritten, runtime_activity
export primal_type, shadow_type, tape_type

import Base: unwrapva, isvarargtype, unwrap_unionall, rewrap_unionall

"""
    forward(fwdconfig, func::Annotation{typeof(f)}, RT::Type{<:Annotation}, args::Annotation...)

Calculate the forward derivative. The first argument is a [`FwdConfig](@ref) object
describing parameters of the differentiation.
The second argument `func` is the callable for which the rule applies to.
Either wrapped in a [`Const`](@ref)), or a [`Duplicated`](@ref) if it is a closure.
The third argument is the return type annotation, and all other arguments are the annotated function arguments.
"""
function forward end

"""
    FwdConfig{NeedsPrimal, NeedsShadow, Width, RuntimeActivity}
    FwdConfigWidth{Width} = FwdConfig{<:Any, <:Any, Width}

Configuration type to dispatch on in custom forward rules (see [`forward`](@ref).
* `NeedsPrimal` and `NeedsShadow`: boolean values specifying whether the primal and shadow (resp.) should be returned. 
* `Width`: an integer that specifies the number of adjoints/shadows simultaneously being propagated.
* `RuntimeActivity`: whether runtime activity is enabled.

Getters for the type parameters are provided by `needs_primal`, `needs_shadow`, `width` and `runtime_activity`.
"""
struct FwdConfig{NeedsPrimal, NeedsShadow, Width, RuntimeActivity} end
const FwdConfigWidth{Width} = FwdConfig{<:Any,<:Any,Width}

@inline needs_primal(::FwdConfig{NeedsPrimal}) where NeedsPrimal = NeedsPrimal
@inline needs_shadow(::FwdConfig{<:Any, NeedsShadow}) where NeedsShadow = NeedsShadow

@inline width(::FwdConfig{<:Any, <:Any, Width}) where Width = Width
@inline runtime_activity(::FwdConfig{<:Any, <:Any, <:Any, RuntimeActivity}) where RuntimeActivity = RuntimeActivity


"""
    RevConfig{NeedsPrimal, NeedsShadow, Width, Overwritten, RuntimeActivity}
    RevConfigWidth{Width} = RevConfig{<:Any, <:Any, Width}

Configuration type to dispatch on in custom reverse rules (see [`augmented_primal`](@ref) and [`reverse`](@ref)).
* `NeedsPrimal` and `NeedsShadow`: boolean values specifying whether the primal and shadow (resp.) should be returned. 
* `Width`: an integer that specifies the number of adjoints/shadows simultaneously being propagated.
* `Overwritten`: a tuple of booleans of whether each argument (including the function itself) is modified between the 
   forward and reverse pass (true if potentially modified between).
* `RuntimeActivity`: whether runtime activity is enabled.

Getters for the four type parameters are provided by `needs_primal`, `needs_shadow`, `width`, `overwritten`, and `runtime_activity`.
"""
struct RevConfig{NeedsPrimal, NeedsShadow, Width, Overwritten, RuntimeActivity} end
const RevConfigWidth{Width} = RevConfig{<:Any,<:Any, Width}

@inline needs_primal(::RevConfig{NeedsPrimal}) where NeedsPrimal = NeedsPrimal
@inline needs_shadow(::RevConfig{<:Any, NeedsShadow}) where NeedsShadow = NeedsShadow
@inline width(::RevConfig{<:Any, <:Any, Width}) where Width = Width
@inline overwritten(::RevConfig{<:Any, <:Any, <:Any, Overwritten}) where Overwritten = Overwritten
@inline runtime_activity(::RevConfig{<:Any, <:Any, <:Any, <:Any, RuntimeActivity}) where RuntimeActivity = RuntimeActivity

"""
    primal_type(::RevConfig, ::Type{<:Annotation{RT}})

Compute the exepcted primal return type given a reverse mode config and return activity
"""
@inline primal_type(config::RevConfig, ::Type{<:Annotation{RT}}) where RT = needs_primal(config) ? RT : Nothing

"""
    shadow_type(::RevConfig, ::Type{<:Annotation{RT}})

Compute the exepcted shadow return type given a reverse mode config and return activity
"""
@inline shadow_type(config::RevConfig, ::Type{<:Annotation{RT}}) where RT = needs_shadow(config) ? (width(config) == 1 ? RT : NTuple{width(config), RT}) : Nothing

"""
    AugmentedReturn(primal, shadow, tape)

Augment the primal return value of a function with its shadow, as well as any additional information needed to correctly 
compute the reverse pass, stored in `tape`.

Unless specified by the config that a variable is not overwritten, rules must assume any arrays/data structures/etc are 
overwritten between the forward and the reverse pass. Any floats or variables passed by value are always preserved as is 
(as are the arrays themselves, just not necessarily the values in the array).

See also [`augmented_primal`](@ref).
"""
struct AugmentedReturn{PrimalType,ShadowType,TapeType}
    primal::PrimalType
    shadow::ShadowType
    tape::TapeType
end
@inline primal_type(::Type{AugmentedReturn{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = PrimalType
@inline primal_type(::AugmentedReturn{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = PrimalType
@inline shadow_type(::Type{AugmentedReturn{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = ShadowType
@inline shadow_type(::AugmentedReturn{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = ShadowType
@inline tape_type(::Type{AugmentedReturn{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = TapeType
@inline tape_type(::AugmentedReturn{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = TapeType
struct AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}
    primal::PrimalType
    shadow::ShadowType
    tape::TapeType
end
@inline primal_type(::Type{AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = PrimalType
@inline primal_type(::AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = PrimalType
@inline shadow_type(::Type{AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = ShadowType
@inline shadow_type(::AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = ShadowType
@inline tape_type(::Type{AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}}) where {PrimalType,ShadowType,TapeType} = TapeType
@inline tape_type(::AugmentedReturnFlexShadow{PrimalType,ShadowType,TapeType}) where {PrimalType,ShadowType,TapeType} = TapeType
"""
    augmented_primal(::RevConfig, func::Annotation{typeof(f)}, RT::Type{<:Annotation}, args::Annotation...)

Must return an [`AugmentedReturn`](@ref) type.
* The primal must be the same type of the original return if `needs_primal(config)`, otherwise nothing.
* The shadow must be nothing if needs_shadow(config) is false. If width is 1, the shadow should be the same
  type of the original return. If the width is greater than 1, the shadow should be NTuple{original return, width}.
* The tape can be any type (including Nothing) and is preserved for the reverse call.
"""
function augmented_primal end

"""
    reverse(::RevConfig, func::Annotation{typeof(f)}, dret::Active, tape, args::Annotation...)
    reverse(::RevConfig, func::Annotation{typeof(f)}, ::Type{<:Annotation), tape, args::Annotation...)

Takes gradient of derivative, activity annotation, and tape. If there is an active return dret is passed
as Active{T} with the derivative of the active return val. Otherwise dret is passed as Type{Duplicated{T}}, etc.
"""
function reverse end

function _annotate(@nospecialize(T))
    if isvarargtype(T)
        VA = T
        T = _annotate(Core.Compiler.unwrapva(VA))
        if isdefined(VA, :N)
            return Vararg{T, VA.N}
        else
            return Vararg{T}
        end
    else
        return TypeVar(gensym(), Annotation{T})
    end
end
function _annotate_tt(@nospecialize(TT0))
    TT = Base.unwrap_unionall(TT0)
    ft = TT.parameters[1]
    tt = map(T->_annotate(Base.rewrap_unionall(T, TT0)), TT.parameters[2:end])
    return ft, tt
end

function has_frule_from_sig(@nospecialize(TT);
                            world::UInt=Base.get_world_counter(),
                            method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                            caller::Union{Nothing,Core.MethodInstance}=nothing)
    ft, tt = _annotate_tt(TT)
    TT = Tuple{<:FwdConfig, <:Annotation{ft}, Type{<:Annotation}, tt...}
    return isapplicable(forward, TT; world, method_table, caller)
end

function has_rrule_from_sig(@nospecialize(TT);
                            world::UInt=Base.get_world_counter(),
                            method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                            caller::Union{Nothing,Core.MethodInstance}=nothing)
    ft, tt = _annotate_tt(TT)
    TT = Tuple{<:RevConfig, <:Annotation{ft}, Type{<:Annotation}, tt...}
    return isapplicable(augmented_primal, TT; world, method_table, caller)
end

# `hasmethod` is a precise match using `Core.Compiler.findsup`,
# but here we want the broader query using `Core.Compiler.findall`.
# Also add appropriate backedges to the caller `MethodInstance` if given.
function isapplicable(@nospecialize(f), @nospecialize(TT);
                      world::UInt=Base.get_world_counter(),
                      method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                      caller::Union{Nothing,Core.MethodInstance}=nothing)
    tt = Base.to_tuple_type(TT)
    sig = Base.signature_type(f, tt)
    @static if VERSION < v"1.7.0"
        return !isempty(Base._methods_by_ftype(sig, -1, world))
    end
    mt = ccall(:jl_method_table_for, Any, (Any,), sig)
    mt isa Core.MethodTable || return false
    if method_table === nothing
        method_table = Core.Compiler.InternalMethodTable(world)
    end
    result = Core.Compiler.findall(sig, method_table; limit=-1)
    (result === nothing || result === missing) && return false
    @static if isdefined(Core.Compiler, :MethodMatchResult)
        (; matches) = result
    else
        matches = result
    end
    fullmatch = Core.Compiler._any(match::Core.MethodMatch->match.fully_covers, matches)
    if caller !== nothing
        fullmatch || add_mt_backedge!(caller, mt, sig)
    end
    if Core.Compiler.isempty(matches)
        return false
    else
        if caller !== nothing
            for i = 1:Core.Compiler.length(matches)
                match = Core.Compiler.getindex(matches, i)::Core.MethodMatch
                edge = Core.Compiler.specialize_method(match)::Core.MethodInstance
                add_backedge!(caller, edge, sig)
            end
        end
        return true
    end
end

function add_backedge!(caller::Core.MethodInstance, callee::Core.MethodInstance, @nospecialize(sig))
    ccall(:jl_method_instance_add_backedge, Cvoid, (Any, Any, Any), callee, sig, caller)
    return nothing
end

function add_mt_backedge!(caller::Core.MethodInstance, mt::Core.MethodTable, @nospecialize(sig))
    ccall(:jl_method_table_add_backedge, Cvoid, (Any, Any, Any), mt, sig, caller)
    return nothing
end

function issupported()
    @static if VERSION < v"1.7.0"
        return false
    else
        return true
    end
end

"""
    inactive(func::typeof(f), args...)

Mark a particular function as always being inactive in both its return result and the function call itself.
"""
function inactive end

function is_inactive_from_sig(@nospecialize(TT);
                              world::UInt=Base.get_world_counter(),
                              method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                              caller::Union{Nothing,Core.MethodInstance}=nothing)
    return isapplicable(inactive, TT; world, method_table, caller)
end

"""
    inactive_noinl(func::typeof(f), args...)

Mark a particular function as always being inactive in both its return result and the function call itself,
but do not prevent inlining of the function.
"""
function inactive_noinl end

function is_inactive_noinl_from_sig(@nospecialize(TT);
                              world::UInt=Base.get_world_counter(),
                              method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                              caller::Union{Nothing,Core.MethodInstance}=nothing)
    return isapplicable(inactive_noinl, TT; world, method_table, caller)
end

"""
    noalias(func::typeof(f), args...)

Mark a particular function as always being a fresh allocation which does not alias any other 
accessible memory.
"""
function noalias end

function noalias_from_sig(@nospecialize(TT);
                              world::UInt=Base.get_world_counter(),
                              method_table::Union{Nothing,Core.Compiler.MethodTableView}=nothing,
                              caller::Union{Nothing,Core.MethodInstance}=nothing)
    return isapplicable(noalias, TT; world, method_table, caller)
end

"""
    inactive_type(::Type{Ty})

Mark a particular type `Ty` as always being inactive.
"""
inactive_type(::Type) = false

@inline EnzymeCore.set_runtime_activity(::M, ::Config) where {M<:Mode, Config <: Union{FwdConfig, RevConfig}} = EnzymeCore.set_runtime_activity(M, runtime_activity(Config))

end # EnzymeRules
