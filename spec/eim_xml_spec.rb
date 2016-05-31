require "eim_xml/dsl"

module Module.new::M
	include EimXML
	EDSL = EimXML::DSL

	describe PCString do
		it ".encode" do
			PCString.encode("<>\"'&").should == "&lt;&gt;&quot;&apos;&amp;"
			PCString.encode("&test;").should == "&amp;test;"
			PCString.encode("&amp;").should == "&amp;amp;"
			PCString.encode(:'sym&').should == "sym&amp;"
		end

		it ".new" do
			PCString.new("&").encoded_string.should == "&amp;"
			PCString.new("&", true).encoded_string.should == "&"
			pcs = PCString.new(:'sym&')
			pcs.encoded_string.should == "sym&amp;"
			pcs.src.should == :'sym&'
		end

		describe ".[]" do
			it "should return itself when given object is a PCString" do
				pcs = PCString.new("s")
				PCString[pcs].should equal(pcs)
			end

			it "should return PCString.new(obj) if given obj is not a PCString" do
				o = "str"
				r = PCString[o]
				r.is_a?(EimXML::PCString)
				r.src.should == o
			end
		end

		it "#==" do
			PCString.new("str").should == PCString.new("str")
			PCString.new("&").should == "&"
			PCString.new("&", true).should_not == "&"
			PCString.new("&", true).should == PCString.new("&", true)
			PCString.new("&").should == PCString.new("&amp;", true)
		end

		describe "#write_to" do
			before do
				@pc = PCString.new("&amp;")
			end

			it "should return encoded string" do
				@pc.write_to.should == "&amp;amp;"
			end

			it "should return given destination" do
				s = ""
				@pc.write_to(s).should be_equal(s)
			end
		end
	end

	describe Comment do
		it ".new should raise error if given string include '--'" do
			lambda{Comment.new("--")}.should raise_error(ArgumentError)
		end

		describe "#write_to" do
			it "should return comment with markup" do
				Comment.new("flat comment").write_to.should == "<!-- flat comment -->"
				Comment.new("multi-line\ncomment").write_to.should == "<!-- multi-line\ncomment -->"
				Comment.new("&").write_to.should == "<!-- & -->"
			end

			it "should return given destination" do
				s = ""
				Comment.new("dummy").write_to(s).should be_equal(s)
			end
		end
	end

	describe Element do
		class Dummy < Element
			def chgname(name)
				self.name = name
			end
		end

		it "#name" do
			e = Element.new("el")
			e.name.should == :el
			lambda{e.name="changed"}.should raise_error(NoMethodError)

			d = Dummy.new("el1")
			d.name.should == :el1
			d.chgname(:el2)
			d.name.should == :el2
			d.chgname("el3")
			d.name.should == :el3
		end

		it "#attributes should return hash whose keys are Symbol" do
			e = Element.new("el", "a1"=>"v1", :a2=>"v2", "a3"=>nil)
			e.name.should == :el
			e.attributes.should == {:a1=>"v1", :a2=>"v2", :a3=>nil}
		end

		it "#[]" do
			e = Element.new(:el, :attr=>"value")
			e << "test"
			e[:attr].should == "value"
			e[0].should == "test"
		end

		it "#add_attribute" do
			e = Element.new("el")
			e.add_attribute("key_str", "value1")
			e.add_attribute(:key_sym, "value2")
			e.attributes.should == {:key_str=>"value1", :key_sym=>"value2"}
			e.add_attribute(:nil, nil)
			e.attributes.should == {:key_str=>"value1", :key_sym=>"value2", :nil=>nil}
		end

		it "#del_attribute" do
			e = Element.new("el", {:a1=>"v1", :a2=>"v2"})
			e.del_attribute("a1")
			e.attributes.should == {:a2=>"v2"}
			e.del_attribute(:a2)
			e.attributes.should == {}
		end

		it "#contents" do
			sub = Element.new("sub")
			e = Element.new("el") << "String1" << "String2" << sub
			e.contents.should == ["String1", "String2", sub]
		end

		it "#add" do
			e = Element.new("el").add(Element.new("sub"))
			e.should be_kind_of(Element)
			e.name.should == :el

			e = Element.new("el")
			e.add(Element.new("sub1"))
			e.add([Element.new("sub2").add("text"), "string"])
			e.contents.should == [Element.new("sub1"), Element.new("sub2").add("text"), "string"]

			e = Element.new("el")
			e.add(nil)
			e.contents.size.should == 0

			e = Element.new("el").add(:symbol)
			e.contents.should == [:symbol]
			e.to_s.should == "<el>symbol</el>"

			e = Element.new("super") << Element.new("sub")
			e.name.should == :super
			e.contents.should == [Element.new("sub")]
		end

		describe "#write_to" do
			it "should return flatten string" do
				Element.new("e").write_to.should == "<e />"

				e = Element.new("super")
				e << Element.new("sub")
				e.write_to.should == "<super><sub /></super>"
				e << Element.new("sub2")
				e.write_to.should == "<super><sub /><sub2 /></super>"

				e = Element.new("super") << "content1"
				s = Element.new("sub")
				s << "content2"
				e << s
				e.write_to.should == "<super>content1<sub>content2</sub></super>"

				e = Element.new("el")
				e.attributes["a1"] = "v1"
				e.attributes["a2"] = "'\"<>&"
				s = e.write_to
				s.should =~ /\A<el ([^>]*) \/>\z/
				s.should =~ /a1='v1'/
				s.should =~ /a2='&apos;&quot;&lt;&gt;&amp;'/
			end

			it "should return string without attribute whose value is nil or false" do
				s = EimXML::Element.new("e", :attr1=>"1", :attr2=>true, :attr3=>nil, :attr4=>false).write_to
				re = /\A<e attr(.*?)='(.*?)' attr(.*?)='(.*?)' \/>\z/
				s.should match(re)
				s =~ /\A<e attr(.*?)='(.*?)' attr(.*?)='(.*?)' \/>\z/
				[[$1, $2], [$3, $4]].sort.should == [["1", "1"], ["2", "true"]]
			end

			it "should return same string whenever name of element given with string or symbol" do
				sym = Element.new(:tag, :attr=>"value")
				str_name = Element.new("tag", :attr=>"value")
				str_attr = Element.new(:tag, "attr"=>"value")

				str_name.write_to.should == sym.write_to
				str_attr.write_to.should == sym.write_to
			end
		end

		it "encode special characters" do
			e = Element.new("el") << "&\"'<>"
			e << PCString.new("&\"'<>", true)
			e.attributes["key"] = PCString.new("&\"'<>", true)
			e.to_s.should == %[<el key='&\"'<>'>&amp;&quot;&apos;&lt;&gt;&\"'<></el>]
		end

		it "#dup" do
			e = Element.new("el")
			e.attributes["key"] = "value"
			e << "String"
			e << "Freeze".freeze
			s = Element.new("sub")
			s.attributes["subkey"] = "subvalue"
			e << s
			f = e.dup

			f.attributes.object_id.should == e.attributes.object_id
			f.contents.object_id.should == e.contents.object_id

			f.to_s.should == e.to_s
		end

		it "#clone" do
			e = Element.new("el")
			e.attributes["key"] = "value"
			e << "String"
			e << "Freeze".freeze
			s = Element.new("sub")
			s.attributes["subkey"] = "subvalue"
			e << s
			f = e.clone

			f.attributes.object_id.should == e.attributes.object_id
			f.contents.object_id.should == e.contents.object_id

			f.to_s.should == e.to_s
		end

		it "#==" do
			e1 = Element.new("el")
			e1.attributes["key"] = "value"
			s = Element.new("sub")
			s << "String"
			e1 << s
			e2 = e1.dup
			e2.should == e1

			e3 = Element.new("e")
			e3.attributes["key"] = "value"
			s = Element.new("sub")
			s << "String"
			e3 << s
			e3.should_not == e1

			e3 = Element.new("e")
			e3.attributes["k"] = "value"
			s = Element.new("sub")
			s << "String"
			e3 << s
			e3.should_not == e1

			e3 = Element.new("e")
			e3.attributes["key"] = "v"
			s = Element.new("sub")
			s << "String"
			e3 << s
			e3.should_not == e1

			e3 = Element.new("e")
			e3.attributes["key"] = "value"
			s = Element.new("sub")
			s << "S"
			e3 << s
			e3.should_not == e1

			e3 = Element.new("e")
			e3.attributes["key"] = "value"
			s = Element.new("s")
			s << "String"
			e3 << s
			e3.should_not == e1

			"string".should_not == e1
		end

		describe ".new" do
			it "should convert name of attributes to Symbol" do
				e = Element.new(:e, "a"=>"v")
				e.attributes.keys.should == [:a]
				e[:a].should == "v"
			end

			it "with block" do
				base = nil
				e = Element.new("base") do |b|
					b["attr"]="value"
					b << Element.new("sub")
					base = b
				end
				base.object_id.should == e.object_id

				e2 = Element.new("base", :attr=>"value")
				e2 << Element.new("sub")
				e2.should == e

				e = Element.new("base") do |e|
					e <<= Element.new("sub1") do |e|
						e <<= Element.new("sub12")
					end
					e <<= Element.new("sub2")
				end
				base = Element.new("base")
				sub1 = Element.new("sub1")
				sub1 << Element.new("sub12")
				sub2 = Element.new("sub2")
				base << sub1  << sub2
				e.should == base
			end
		end

		it "#match" do
			e = Element.new(:tag, :attr=>"value")
			e.match(:tag).should be true
			e.match(:tag, :attr=>"value").should be true
			e.match(:t).should be false
			e.match(:tag, :attr2=>"value").should be false
			e.match(:tag, :attr=>"value2").should be false
			e.match(:tag, :attr=>/val/).should be true

			e.match(Element.new(:tag)).should be true
			e.match(Element.new(:tag, :attr=>"value")).should be true
			e.match(Element.new(:tag, :attr=>/alu/)).should be true
			e.match(Element.new(:t)).should be false
			e.match(Element.new(:tag, :attr2=>"value")).should be false
			e.match(Element.new(:tag, :attr=>"value2")).should be false
			e.match(Element.new(:tag, :attr=>/aul/)).should be false
			e.match(Element.new(:tag, :attr=>PCString.new("value"))).should be true
			Element.new(:tag, :attr=>PCString.new("value")).should match(e)

			e.match(Element.new(:tag, :attr=>nil)).should be false
			e.match(Element.new(:tag, :nonattr=>nil)).should be true

			(!!e.match(/ag/)).should be true
			(!!e.match(/elem/)).should be false

			e.match(Element).should be true
			e.match(Dummy).should be false
			e.match(String).should be false

			e = Element.new(:element)
			e << Element.new(:sub)
			e << "text"
			e.match(EDSL.element(:element){element(:sub)}).should be true
			e.match(EDSL.element(:element){element(:other)}).should be false
			e.match(EDSL.element(:element){add("text")}).should be true
			e.match(EDSL.element(:element){add("other")}).should be false
			e.match(EDSL.element(:element){add(/ex/)}).should be true
			e.match(EDSL.element(:element){add(/th/)}).should be false
			e.match(EDSL.element(:element){add(/sub/)}).should be false

			e = Element.new(:t, :a=>"&")
			e.should match(Element.new(:t, :a=>"&"))
			e.should match(Element.new(:t, :a=>PCString.new("&amp;", true)))
			e.should match(Element.new(:t, :a=>PCString.new("&")))

			Element.new(:t, "a"=>"v").should match(Element.new(:t, :a=>"v"))
		end

		it "#=~" do
			e = Element.new(:tag, :attr=>"value", :a2=>"v2")
			e.should =~ :tag
			e.should =~ Element.new(:tag)
			e.should =~ Element.new(:tag, :a2=>"v2")
			e.should =~ Element.new(:tag, :attr=>/alu/)
			e.should =~ Element.new(:tag, :attr=>PCString.new("value"))
			e.should_not =~ :t
			e.should_not =~ Element.new(:t)
			e.should_not =~ Element.new(:tag, :attr=>/aul/)

			e = Element.new(:t, :a=>"&")
			e.should =~ Element.new(:t, :a=>"&")
			e.should =~ Element.new(:t, :a=>PCString.new("&amp;", true))
			e.should =~ Element.new(:t, :a=>PCString.new("&"))
		end

		%w[has? has_element? include?].each do |method|
			it "##{method}" do
				e = Element.new(:base) do |b|
					b <<= Element.new(:sub) do |s|
						s <<= Element.new(:deep) do |d|
							d << "text"
							d << PCString.new("&amp;", true)
							d << "<"
						end
					end
					b <<= Element.new(:sub, :attr=>"value")
				end

				e.send(method, :sub).should be true
				e.send(method, :sub, :attr=>"value").should be true
				e.send(method, :sub, :attr=>"value", :attr2=>"").should be false
				e.send(method, :deep).should be true

				e.send(method, String).should be true
				e.send(method, PCString).should be true

				d = Element.new(:deep)
				d << "text"
				d << PCString.new("&amp;", true)
				d << "<"
				e.send(method, d).should be true

				d = Element.new(:deep)
				d << PCString.new("text", true)
				d << "&"
				d << PCString.new("&lt;", true)
				e.send(method, d).should be true
			end
		end

		it "#find" do
			s1 = Element.new(:sub)
			d = Element.new(:deep)
			d << "3rd"
			s1 << "2nd" << d
			s2 = Element.new(:sub, :attr=>"value")
			e = Element.new(:base)
			e << "1st" << s1 << s2

			e.find(:deep).should be_kind_of(Element)
			e.find(:deep).name.should == :found
			e.find(:deep).contents.should == [d]
			e.find(:sub).contents.should == [s1, s2]
			e.find(//).contents.should == [e, s1, d, s2]
			e.find(:sub, :attr=>"value").contents.should == [s2]
			e.find(String).contents.should == ["1st", "2nd", "3rd"]
		end
	end
end
