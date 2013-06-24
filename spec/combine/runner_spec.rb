require 'spec_helper'
require 'tempfile'

module Tangle
  describe Runner do
    @@files = []

    def fixture_file(name, *data)
      f = Tempfile.new(name)
      f.write(data.map(&:to_json).join("\n"))
      f.close
      @@files << f
      f.path
    end

    after :all do
      @@files.each { |f| f.unlink }
    end

    let :stdout do
      StringIO.new
    end

    let :result do
      stdout.string.split("\n").map do |l|
        JSON.parse(l)
      end
    end

    context 'merging' do
      it 'merges two json files from right to left' do
        foo = fixture_file 'foo', { id: 1, a: 1, x: 1 }, { id: 2, a: 2, x: 2 }
        bar = fixture_file 'bar', { id: 1, b: 3, x: 3 }, { id: 2, b: 4, x: 4 }

        described_class.new('merge', [foo, bar], { :out => stdout }).run
        result.should == [
                          { 'id' => 1, 'a' => 1, 'b' => 3, 'x' => 3 },
                          { 'id' => 2, 'a' => 2, 'b' => 4, 'x' => 4 }
                         ]
      end

      it 'does not include documents where the match key is missing' do
        foo = fixture_file 'foo', { a: 1 }, { x: 1337 }
        bar = fixture_file 'bar', { b: 2 }

        described_class.new('merge', [foo, bar], { :out => stdout, :keys => ['x'] }).run
        result.should == [
                          { 'x' => 1337 }
                         ]
      end

      it 'allows for one key per file' do
        foo = fixture_file 'foo', { foo: 1, a: 1 }, { foo: 2, a: 2 }
        bar = fixture_file 'bar', { bar: 1, b: 3 }, { bar: 2, b: 4 }

        described_class.new('merge', [foo, bar], { :out => stdout, :keys => ['foo', 'bar'] }).run
        result.should == [
                          { 'foo'=> 1, 'bar' => 1, 'a' => 1, 'b' => 3 },
                          { 'foo'=> 2, 'bar' => 2, 'a' => 2, 'b' => 4 }
                         ]
      end
    end

    it 'raises an exception if duplicate keys are encountered in the first file' do
      foo = fixture_file 'foo', { id: 1 }, { id: 1 }
      bar = fixture_file 'bar'

      expect { described_class.new('merge', [foo, bar], { :out => stdout }).run }.to raise_error(ArgumentError)
    end

    it 'uses the first match on the right for merge' do
      foo = fixture_file 'foo', { id: 1, a: 1 }
      bar = fixture_file 'bar', { id: 1, a: 2 }, { id: 1, a: 3 }

      described_class.new('merge', [foo, bar], { :out => stdout }).run
      result.should == [
                        { 'id'=> 1, 'a' => 2 }
                       ]
    end

    context 'attaching' do
      it 'attaches matching documents from the second file to the first under `children`' do
        foo = fixture_file 'foo', { id: 1, a: 1, x: 1 }, { id: 2, a: 2, x: 2 }
        bar = fixture_file 'bar', { id: 1, b: 3, x: 3 }, { id: 2, b: 4, x: 4 }

        described_class.new('attach', [foo, bar], { :out => stdout }).run
        result.should == [
                          { 'id' => 1, 'a' => 1, 'x' => 1, 'children' => [ { 'id' => 1, 'b' => 3, 'x' => 3 } ] },
                          { 'id' => 2, 'a' => 2, 'x' => 2, 'children' => [ { 'id' => 2, 'b' => 4, 'x' => 4 } ] }
                         ]
      end

      it 'attaches multiple documents to the same object from the first file' do
        foo = fixture_file 'foo', { id: 1, a: 1, x: 1 }
        bar = fixture_file 'bar', { id: 1, b: 3, x: 3 }, { id: 1, b: 4, x: 4 }

        described_class.new('attach', [foo, bar], { :out => stdout }).run
        result.should == [
                          { 'id' => 1, 'a' => 1, 'x' => 1, 'children' => [ { 'id' => 1, 'b' => 3, 'x' => 3 }, { 'id' => 1, 'b' => 4, 'x' => 4 } ] },
                         ]
      end

      it 'attaches matching documents at the given keys' do
        foo = fixture_file 'foo', { id: 1, a: 1 }
        bar = fixture_file 'bar', { id: 1, b: 2 }
        baz = fixture_file 'bar', { id: 1, c: 3 }

        described_class.new('attach', [foo, bar, baz], { :out => stdout, :attach_keys => ['bar', 'baz'] }).run
        result.should == [
                          { 'id' => 1, 'a' => 1, 'bar' => [ { 'id' => 1, 'b' => 2 } ], 'baz' => [ { 'id' => 1, 'c' => 3 } ] },
                         ]
      end

      it 'raises error if the attached keys are not named and more than one' do
        foo = fixture_file 'foo', { id: 1, a: 1, x: 1 }, { id: 2, a: 2, x: 2 }
        bar = fixture_file 'bar', { id: 1, b: 3, x: 3 }, { id: 2, b: 4, x: 4 }
        expect { described_class.new('attach', [foo, bar, bar], { :out => stdout }).run }.to raise_error(ArgumentError)
      end
    end
  end
end
