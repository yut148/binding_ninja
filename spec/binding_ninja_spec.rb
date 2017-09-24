require "spec_helper"

RSpec.describe BindingNinja do
  class Foo
    extend BindingNinja

    def foo(b, arg1, arg2, *rest, abc: 1, **options)
      b.local_variables
    end

    def foo2(b)
      b.local_variable_set("hoge", 100)
      b
    end

    def foo3(b, a = 1)
      b.local_variables if b
    end

    def foo4(b, a = 1)
      b.local_variables if b
    end

    def foo5(b)
      b.local_variables if b
    end

    def enable_auto_inject_binding?
      true
    end

    auto_inject_binding :foo
    auto_inject_binding :foo2
    auto_inject_binding :foo3, if: ENV["ENABLE_BINDING_NINJA"]
    auto_inject_binding :foo4, if: ->(obj) { obj.class.to_s != "Foo" }
    auto_inject_binding :foo5, if: :enable_auto_inject_binding?

    alias :hoge :foo2
  end

  class Bar < Foo
    def enable_auto_inject_binding?
      false
    end
  end

  klass = Class.new do
    extend BindingNinja
    auto_inject_binding def foo(b)
      b.local_variables
    end
  end

  it "inject binding" do
    aggregate_failures do
      hoge = 1
      obj = Foo.new
      expect(obj.foo(1, 2, 3, 4, abc: 2, def: 10)).to match_array([:hoge, :obj, :klass])
      obj.hoge
      expect(hoge).to eq(100)
      if ENV["ENABLE_BINDING_NINJA"]
        puts "ENABLE_BINDING_NINJA=#{ENV["ENABLE_BINDING_NINJA"]}"
        expect(obj.foo3).to match_array([:hoge, :obj, :klass])
      else
        expect(obj.foo3).to be_nil
      end
      expect(obj.foo4).to be_nil
      expect(obj.foo5).to match_array([:hoge, :obj, :klass])
      expect(Bar.new.foo4).to match_array([:hoge, :obj, :klass])
      expect(Bar.new.foo5).to be_nil
      expect(klass.new.foo).to match_array([:hoge, :obj, :klass])
    end
  end

  it "create extension module" do
    expect(BindingNinja.send(:instance_variable_get, "@auto_inject_binding_extensions")[Foo]).to be_a(Module)
    expect(Foo.send(:class_variable_get, "@@__auto_inject_binding_options")).to match({
      :foo3 => nil,
      :foo4 => an_instance_of(Proc),
      :foo5 => :enable_auto_inject_binding?,
    })
    expect(Bar.send(:class_variable_get, "@@__auto_inject_binding_options")).to match({
      :foo3 => nil,
      :foo4 => an_instance_of(Proc),
      :foo5 => :enable_auto_inject_binding?,
    })
    expect(klass.send(:class_variable_get, "@@__auto_inject_binding_options")).to match({})
  end
end