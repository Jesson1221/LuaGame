--[[
--filename: FObject.lua
--author: lidengfeng
--email: libyyu@qq.com
--time: 2017/2/19
--comment: 是Lua面向对象
================== Object.lua内容 =======================
]]
local FClass = {}
FClass.classList = {} --保存所有已经定义过的类

--类的类型: 类和接口, 接口也是一种类
FClass.TYPE_CLASS = "Class"
FClass.TYPE_INTERFACE = "Interface"

function FClass.isExist(className)
	return FClass.classList[className] ~= nil
end

function FClass.defaultClassName( )
	local start = 1
	local toFind = FClass.TYPE_CLASS .. start
	for _,v in pairs(FClass.classList) do
		if FClass.isExist(toFind) then
			start = start + 1
			toFind = FClass.TYPE_CLASS .. start
		else
			return toFind
		end
	end
	return FClass.TYPE_CLASS .. (#FClass.classList+1)
end

function FClass.defaultInterfaceName( )
	local start = 1
	local toFind = FClass.TYPE_INTERFACE .. start
	for _,v in pairs(FClass.classList) do
		if FClass.isExist(toFind) then
			start = start + 1
			toFind = FClass.TYPE_INTERFACE .. start
		else
			return toFind
		end
	end
	return FClass.TYPE_INTERFACE .. (#FClass.classList +1)
end


--将定义的类注册,防止重复定义
function FClass.register(className,clazz)
	if(FClass.isExist(className)) then return end
	FClass.classList[className]=clazz
end
function FClass.getDefinedClass(className)
	return FClass.classList[className]
end

-- 将错误信息返回而不是直接error, 这样在外层再通过error的level2 抛出异常,就能更精确定位到调用者
function FClass._checkValid(class, clsType)
	clsType = clsType or FClass.TYPE_CLASS
	if(class==nil) then
		return clsType .. " 未定义!!"
	end
	if(type(class)~="table") then
		return "\""..tostring(class).."\" 不是一个" .. clsType .."!!"
	end
	local b = false
	for k, v in pairs(FClass.classList) do
		if(v == class) then
			b = true
		end
	end
	if(not b) then
		return clsType .. " ".. tostring(class) .. " 未定义!!"
	end

	if (clsType==FClass.TYPE_CLASS and class.__classType~=FClass.TYPE_CLASS) or (clsType==FClass.TYPE_INTERFACE and class.__classType~=FClass.TYPE_INTERFACE) then
		return "\"" .. class.className .. "\" 不是一个 "..clsType.."!!"
	end

	return nil
end

--定义一个类. 由于无法区分是没有传入extendsCls还是传入了一个错误的extendsCls,所以提供了define2来自动继承自Object. 这个方法是强制传入Object方法
--@param className 类名.字符串.
--@param ... 第一个参数是 extends 父类,后面要实现的一组接口.
function FClass.define(className, ...)
	className = className or FClass.defaultClassName()
	local cls
	cls = FClass._define(FClass.TYPE_CLASS, className, ...)
	if (type(cls)=="string") then
		error(cls, 2)
	end

	function cls.new( ... )
		return FClass.new(cls,...)
	end

	return cls
end

function FClass._define(clsType, className, ...)
	if(type(className)~="string") then
		return clsType.." 名称 \""..tostring(className).."\" 无效!!"
	end
	if(FClass.isExist(className)) then
		return clsType.." \""..tostring(className).."\" 重复定义!!"
	end

	local clazz={className=className, __classType=FClass.TYPE_CLASS}
	--保存本类需要实现的接口,且不能重复实现同一接口
	local extendsCls
	local arglen = select("#", ...)
	local err = nil

	-- 说明没有显示传入继承的类
	if(arglen<1) then
		if(className=="Object") then
			extendsCls = nil
		else
			extendsCls = FObject
		end
	else
		extendsCls = select(1,...)
		err = FClass._checkValid(extendsCls,clsType)

		if(err) then
			return err
		end
	end

	clazz.parentClass=extendsCls

	clazz.__implements={}
	local _impl
	for i=2, arglen do
		_impl = select(i, ...)
		--验证接口有效性
		err = FClass._checkValid(_impl, FClass.TYPE_INTERFACE)
		if(err) then
			return err
		end

		--检查接口是否重复继承
		for _,v in ipairs(clazz.__implements) do
			if(v==_impl) then
				return FClass.TYPE_INTERFACE.." \"".._impl.className.."\" 重复继承!!"
			end
		end

		table.insert(clazz.__implements, _impl)
	end

	if(className=="Object") then
		FClass.register(className,clazz)
		return clazz
	end

	FClass.register(className,clazz)

	return clazz
end
--检测当前类以及父类是否实现了相关接口的方法
function FClass._checkImplements(cls, interfaces)
	if(#interfaces<1) then return end

	local pInterface
	for k,v in ipairs(interfaces) do
		--查找当前接口的所有方法是否被实现
		FClass.__checkImplements(cls, v)

		--查找当前接口的父级接口的所有方法是否被实现
		pInterface=v.parentClass
		while(pInterface) do
			FClass.__checkImplements(cls, pInterface)
			pInterface=pInterface.parentClass
		end
	end
end
--检测当前类和父类是否实现了一个接口的所有方法
function FClass.__checkImplements(cls, interface)
	local b=false
	local pcls
	for name, func in pairs(interface) do
		if(type(func)=="function") then
			pcls = cls
			while pcls do
				if pcls[name] ~= nil and type(pcls[name]) == "function" then
					b = true
					break
				end
				pcls = pcls.parentClass
			end
			
			--子类和父类中都没找到,说明没有实现
			if not pcls then
				error("\""..cls.className.."\" 未覆盖 \""..interface.className.."\" 中的抽象方法 "..name.."()")
			end
		end
	end
end
function FClass.createObjectFromClass(class)
	local o={}
	o.class=class
	setmetatable(o,class)

	--设置访问时的操作
	class.__index=function(t,k) --属性和方法从本类开始往父类逐级找

		local v = nil
		local pcls = t.class
		while(pcls) do
			v = rawget(t.class, k)
			if(v) then return v end

			pcls = pcls.parentClass
		end

		return nil
	end

	return o
end

--验证构造参数合法性
function FClass.checkCtor(class, ...)
	if(class==FObject or class.parentClass==nil) then
		return
	end

	--产生一个无参构造.
	if(class._ctor == nil and class.ctor == nil) then
		class._ctor = function() end
	end

	FClass.checkCtor(class.parentClass)
end
--new一个对象的实例
function FClass.new(class, ...)
	FClass._checkValid(class)

	--检查接口的实现情况
	FClass._checkImplements(class, class.__implements)

	--如果都没显示指定无参构造函数,则在checkCtor()中生成一个无参的构造函数
	FClass.checkCtor(class, ...)

	-- 获取参数的真实长度, 用来区分传入的参数在为nil时,到底是调用者填写的nil还是系统默认的nil
	local arglen = select("#", ...)
	--如果当前类没有有参构造,则参数必须为空
	if(class._ctor == nil and arglen ~= 0) then
		error("构造函数错误,不存在有参构造函数. FClass: "..class.className)
	elseif(class._ctor == nil and arglen == 0) then
		error("构造函数错误,不存在无参构造函数. FClass: "..class.className)
	end

	-- 将父类的所有定义的属性拿出来放到一个映射表中
	local attributes = {} -- Map<类名, Map<属名,value> >
	local fields = {}

	-- 将类链表中定义的方法做个列表存放起来. 每个类自己定义的方法都做单独保存,主要为super提供
	local functionsMap = {} -- Map<类名, Map<方法名,func> >
	--保存最后实现的那些方法. 实现多态.
	functionsMap.lastFuncs = {}

	--查找类链
	local _clsListTemp = {}
	local pcls=class
	while(pcls~=nil) do
		table.insert(_clsListTemp, pcls)
		pcls = pcls.parentClass
	end

	--先从上往下依次调用类链中的所有方法.
	local _cls = nil
	for i = #_clsListTemp, 1, -1 do
		_cls = _clsListTemp[i]

		functionsMap[_cls] = {}

		--找出方法,保存到方法列表中
		for k,v in pairs(_cls) do
			--本来应该检查方法名称是否和属性名称重复. java中可以做到方法名和属性名重复, 但lua不行,会覆盖.

			--默认的无参构造函数不存起来,因为会自动都调用一次.
			if(type(v)=="function" and k~="_ctor" and k~="__index" and k~="__newindex") then
				if(k=="getter_ctor" or k=="setter_ctor" or k=="getter__ctor" or k=="setter__ctor") then
					error("不能将构造方法定义为getter或setter方法!!")
				end

				--保存对应的方法列表. 默认指向最后的实现者,但也保存每个类中自己的那个方法,以便通过super调用的时候找到对应的方法.
				functionsMap[_cls][k] = v

				--由于是从上往下调用,所以子类覆盖的方法会被正确指向. 有参构造不能覆盖保存.
				if(k~="ctor") then
					functionsMap.lastFuncs[k] = v
				end
			end
		end
	end

	local obj = {}
	-- obj 是在new之后返回的一个空的代理对象, 真正的对象是这个meta,所有表象上看起来的属性的访问和修改也来自于这个meta.
	-- 这样也方便的模拟实现了 getter 和 setter
	local meta = {class = class, __fields = fields, __attributes = attributes, __functionsMap = functionsMap}

	setmetatable(obj, meta)
	--设置键为弱引用.
	meta.__mode="k"

	--访问属性和方法
	meta.__index = function(t, k)
		if(k=="_ctor") then return nil end

		local m = getmetatable(t)
		if(k=="class") then return m.class end

		local attr,func

		--先从属性查找
		if(m.__fields[k]) then
			return m.__attributes[k]
		end

		attr = m.__attributes[k]

		if(attr~=nil) then return attr end

		-- 判断是否有getter方法,如果有getter方法,优先调用getter方法
		func = m.__functionsMap.lastFuncs["getter_"..k]
		if(func~=nil) then
			return func(t)
		end

		--方法.
		func = m.__functionsMap.lastFuncs[k]
		if(func ~= nil) then return func end

		--如果元表对象中找不到,则从类链中查找. 在java中的表现为用实例化对象去访问它的类的静态属性或方法.
		local pcls = m.class
		while(pcls~=nil) do
			attr = pcls[k]

			if(attr~=nil) then
				--如果是方法, 进行一次代理访问方法, 不会把这个方法返回出去.
				--因为外部可能是冒号访问, 而类的静态方法只能是点号访问, 这样在那些方法内部使用self会出错. 变相的做了限制
				if(type(attr) == "function") then
					return attr()
				end

				return attr
			end

			pcls = pcls.parentClass
		end
		error("attribute \""..k.."\" not found in ".. tostring(t),2)
	end

	--修改属性和方法
	meta.__newindex = function(t, k, v)
		if(k=="class") then
			error("class 是只读属性. \""..m.class.className.."\" !!")
		end

		if(k=="ctor" or k=="_ctor") then
			error("不能将构造方法定义为属性!!")
		end

		local m = getmetatable(t)

		if(m.__functionsMap.lastFuncs[k] and v~=nil) then
			--判断这个方法是否是一个getter,setter方法. 如果是,则不能允许属性存在重复定义
			local stind,endind = string.find(k,"getter_")
			local subname = nil
			if(stind~=nil) then
				subname = string.sub(k,endind+1)
			else
				stind,endind = string.find(k,"setter_")
				if(stind~=nil) then
					subname = string.sub(k,endind+1)
				end
			end

			if(subname) then
				error("不能重新定义Class \"".. m.class.className .."\" 的getter, setter方法 \""..subname.."\" !!")
			--else
			--	error("不能重新定义Class \"".. m.class.className .."\" 的方法 \""..k.."\" !!")
			end
		end

		--改变的值不是一个方法. 就添加到属性列表中
		if(type(v)~="function") then

			-- 判断是否有setter方法,如果有setter方法,优先调用setter方法
			local func = m.__functionsMap.lastFuncs["setter_"..k]
			if(func~=nil) then
				return func(t, v)
			end

			m.__attributes[k] = v
			m.__fields[k] = true
			return
		else
			if m.__fields[k] then
				m.__attributes[k] = v
			end
			-- error("不能为Class \"".. m.class.className .."\" 的实例动态添加方法 \""..k.."\" !!")
			m.__functionsMap.lastFuncs[k] = v
		end
	end
	--print
	local typeName = "\"" .. class.className .. "(".. tostring(obj) .. ")\""
	meta.__tostring = function ( )
		return typeName
	end
	--由于上面已经找出了所有方法, 所以在构造函数中就可以访问那些方法了. 也就是在构造函数中执行一些逻辑.
	for i = #_clsListTemp, 1, -1 do
		_cls = _clsListTemp[i]

		--产生_cls的临时对象
		local __o = FClass.createObjectFromClass(_cls)

		--这里用点号访问,并传入了代理的obj对象,这样在_ctor定义的属性就会保存到obj元表对象meta的 attributes中(通过上面的__newindex操作).
		--如果在_ctor中初始调用逻辑方法,也能在obj元表meta的functionsMap 中正确访问到.
		--如果出现重复定义属性, 这里没有使用像java一样的方式保存在不同类中定义的相同属性的副本.
		--有点像actionscript中一样不能重复定义(as中父类的属性可见性要比子类小,否则就报重复定义的编译级错误).
		--但这里没有实现 private 这样的可见性, 所以全部视为 public. 那自然不允许重复定义属性.
		--理论上应该做一次检查,如果重复定义要报错.但lua没有像其它预编译语言的定义属性的概念,
		--并且我无法知道子类在构造方法内部写self.xx=value 时到底是定义这个属性还是更改它的值(如果它已经在父类中定义了)
		--所以这里统一处理,不存在就定义,存在就覆盖.
		--并且由于ctor 不能被覆盖,在上面存储方法时已经屏蔽了ctor方法,但_ctor方法中可能会调用ctor方法,且此时只能访问自己这个类中的ctor方法,
		--那就要将这个存在的ctor从__o中取出来放到obj的元表中临时保存起来,再调用_ctor时,如果内部又要调用ctor才不会出错,且能正确调用到类链中对应位置的ctor.
		if(__o.ctor~=nil) then
			getmetatable(obj).__functionsMap.lastFuncs.ctor=__o.ctor
		end

		--自动调用了一次每个类的无参构造函数.
		--这里和java不一样, java是当new时不传参数时,才会调用无参构造,且如果这个无参构造里没有显示写super,又会自动调用父类的无参构造.
		--但在这里我无法知道到底有没有在代码内部显示写super, 就不知道是否该自动调用父类的无参构造.
		--如果不自动统一调用,那每个子类都要显示写上无参构造函数并在内部写self:super(class,"_ctor").
		--为了业务统一方便,这里自动调用, 所以在无参构造函数里尽量不要包含对其它函数的调用,免得逻辑重复.
		if(__o._ctor~=nil) then
			__o._ctor(obj)
		end

		--如果子类没有定义他自己的ctor,但子类的_ctor中又写self:ctor()这样的语句,就可能会调用到父类的ctor方法.这是错误的.
		--所以不管_ctor内部是否调用过了ctor,之后都要将临时保存的ctor清除。
		if(__o.ctor~=nil) then
			getmetatable(obj).__functionsMap.lastFuncs.ctor=nil
		end
	end

	--如果存在参数就调用本类的有参的构造ctor(). 父类的有参构造不会被自动调用,只有子类显示写self:super(class, k, ...)
	local arglen = select("#", ...) -- 只有调用者真正的写了参数,即使是nil,才能调用有参构造
	local ctorFunc = arglen~=0 and getmetatable(obj).__functionsMap[class].ctor
	if(ctorFunc) then
		ctorFunc(obj, ...)
	end

	return obj
end
--假如这个super是一个简单实现,没有第一个class作为参数,出现的情况是:
--设有类 A <- B <- C <- D 其中在A类中定义了func1, 在C类中覆盖了func1,并在方法代码内部简单写super(self,"walk").
--现在Class.new(D),并通过D的实例调用func1. 正确的逻辑应该是访问到C 的func1,然后又访问到A 的func1.
--但方法都是冒号访问, 所以用C 类中的func1里的super(self,"walk")这个self的引用实际上是D 的实例. 如果不进行判断,就会陷入死循环.
--这里传入cls就是明确告诉我当前覆盖walk方法的类是哪个, 再从cls的父类继续找到A.
--如果不传入cls, 那我无法知道当前super代码位于哪个类里面, 就可能导致陷入循环(B和C的walk方法里都写生super时就会陷入死循环)
--所以第一个参数class只能通过外部显示传入.
local function super(cls, t, k, ...)
	FClass._checkValid(cls)

	if(instanceof(t,FObject)==false) then
		error("参数类型错误. 不是一个正确的Object实例!!")
	end

	FClass._checkValid(t.class)

	if(type(k)~="string") then
		error("参数类型错误. 使用 super 访问时,只能传入属性或方法的字符串名称!!")
	end
	local m = getmetatable(t)

	local pcls = cls.parentClass
	local func = nil
	if(pcls==nil) then
		error("访问 FClass \""..cls.className.."\" 的父类不存在!!")
	end
	if(k=="ctor") then
		func = m.__functionsMap[pcls][k]
		if(func~=nil) then
			return func(t, ...)
		else
			error("访问 Class \""..t.class.className.."\" super的方法 \""..k.."\" 不存在!!")
		end
	end

	--属性. 这里没有像java一样也保存了父类的相同名称的属性的副本. 即用super时也会得到这个属性最后被改过的那个值
	local attr = m.__attributes[k]
	if(attr~=nil) then
		return attr
	end

	--检查t的class中是否有k方法
	while(pcls~=nil)do
		func = m.__functionsMap[pcls][k]
		if(func~=nil) then
			return func(t, ...)
		end

		pcls = pcls.parentClass
	end

	error("访问 Class \""..t.class.className.."\" super的方法 \""..k.."\" 不存在!!")
end
local _instanceof
-- 一个对象是否是一个类或接口的实例
local function instanceof(obj,class)
	if(obj==nil or type(obj)~="table" or obj.class==nil) then
		-- print("参数错误 1, 不是一个对象!!")
		return false
	end

	FClass._checkValid(class)

	if(rawget(class,"__classType")==nil) then
		error("参数错误 #2,不是一个类!!")
	end
	if(class==FObject) then return true end

	local ocls=obj.class
	if(ocls==class) then return true end
	local pcls,b=nil,false
	--如果是个类,则查找父类
	if(class.__classType == FClass.TYPE_CLASS) then
		pcls=ocls.parentClass
		while(pcls~=nil) do
			if(pcls==class) then return true end
			pcls=pcls.parentClass
		end
	--如果是个接口,则在本类和父类的所有接口中查找
	elseif(class.__classType == FClass.TYPE_INTERFACE) then

		b=_instanceof(ocls,class)
		if(b) then return true end
		pcls=ocls.parentClass

		while(pcls~=nil) do
			b=_instanceof(pcls,class)
			if(b) then return true end
			pcls=pcls.parentClass
		end
	end

	return false
end

local function instanceof2( cls,class )
	if(cls==nil or type(cls)~="table") then
		return false
	end

	FClass._checkValid(class)

	if(rawget(class,"__classType")==nil) then
		error("参数错误 #2,不是一个类!!")
	end
	--if(class==Object) then return true end

	local ocls=cls
	if(ocls==class) then return true end
	local pcls,b=nil,false
	--如果是个类,则查找父类
	if(class.__classType == FClass.TYPE_CLASS) then
		pcls=ocls.parentClass
		while(pcls~=nil) do
			if(pcls==class) then return true end
			pcls=pcls.parentClass
		end
	--如果是个接口,则在本类和父类的所有接口中查找
	elseif(class.__classType == FClass.TYPE_INTERFACE) then

		b=_instanceof(ocls,class)
		if(b) then return true end
		pcls=ocls.parentClass

		while(pcls~=nil) do
			b=_instanceof(pcls,class)
			if(b) then return true end
			pcls=pcls.parentClass
		end
	end

	return false
end

_instanceof=function(cls,class)
	local interfaces,pInterface,b=cls.__implements,nil,false
	if(#interfaces<1) then return false end

	--可能会重复查找相关接口
	for k,v in ipairs(interfaces) do
		if(class==v) then return true end

		--查找当前接口的父级接口的所有方法是否被实现
		pInterface=v.parentClass
		while(pInterface~=nil) do
			if(class==pInterface) then return true end
			pInterface=pInterface.parentClass
		end
	end

	return false
end

-----------------------------------------
--Object
FObject=FClass.define("Object")
function FObject:_ctor()
	--print("Object _ctor")
end

--提供一个便捷访问. 每个类的实例就可以通过 self:super(cls,k,...)来访问
function FObject:super( k, ...)
	super(self.class, self, k, ...)
end


FClass.define("Class") --定义class本身
--接口
Interface=FClass.define("Interface")
function Interface.define(interfaceName, ...)
	interfaceName = interfaceName or FClass.defaultInterfaceName()	
	local cls
	cls = Interface._define(FClass.TYPE_INTERFACE, interfaceName, ...)
	if (type(cls)=="string") then
		error(cls, 2)
	end
	return cls
end
function Interface._define(cls_type,interfaceName,...)
	local arglen, cls,extendsInterface
	arglen = select("#", ...)

	cls = FClass._define(FClass.TYPE_INTERFACE, interfaceName,...)

	cls.__classType=FClass.TYPE_INTERFACE
	return cls
end
--单例模式
LSingleton = FClass.define("Singleton")
function LSingleton.new( ... )
	local mt = {}
	setmetatable( mt ,  {__index = Singleton} )
	return FClass.new(Singleton,...)	
end


FLua = {}

function FLua.Class( ... )
	local theClass
	local arglen = select("#", ...)
	if arglen < 1 then
		theClass = FClass.define()
	elseif arglen == 1 then
		local argfirst = select(1, ...) --select the param
		if type(argfirst) == "string" then --className
			theClass = FClass.define(argfirst)
		elseif argfirst.__classType == FClass.TYPE_CLASS then --baseClass
			theClass = FClass.define(FClass.defaultClassName(),argfirst)
		elseif argfirst.__classType == FClass.TYPE_INTERFACE then
			theClass = FClass.define(FClass.defaultClassName(),FObject,argfirst)
		else
			error("when arguement is one ,it must be (\"string\",\"Class\",\"Interface\")")
		end
	else
		local className = select(1,...)
		local baseClass = select(2,...)
		if type(className) ~=  "string" then
			error("when arguement more than one,arguement #1 must be \"string\",but got "..type(className))
		end
		if baseClass.__classType == FClass.TYPE_CLASS then --baseClass
			theClass = FClass.define(className,baseClass,select(3,...))
		elseif baseClass.__classType == FClass.TYPE_INTERFACE then
			theClass = FClass.define(className,FObject,baseClass,select(3,...))
		else
			error("when arguement more than one,arguement #2 must be a (\"Class\" or \"Interface\" type,but got "..type(baseClass))
		end
	end

	return theClass
end


function FLua.Interface( ... )
	local theInterface
	local arglen = select("#",...)
	if arglen < 1 then
		theInterface = Interface.define()
	else
		local interfaceName = select(1,...)
		theInterface = Interface.define(interfaceName,select(2,...))
	end

	return theInterface
end


function FLua.IsClass( cls )
	local t = cls
	if cls.class ~= nil then
		t = cls.class
	end
	if t.__classType == FClass.TYPE_CLASS then --baseClass
			return 1
	elseif t.__classType == FClass.TYPE_INTERFACE then
		return 2
	else
		return 0
	end
end


return FLua