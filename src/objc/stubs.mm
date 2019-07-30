// TODO: Implement these functions.

#include "..\..\deps\objc4\runtime\objc-private.h"

OBJC_EXPORT void dyld_stub_binder() { assert(false); }

// The original is in libobjc2/arc.mm.
OBJC_EXPORT void objc_delete_weak_refs(id obj) {}

// See i27. This is a workaround, because if we imported
// `dispatch_is_dispatch_object` directly, there would be a cycle.
static bool(*dispatch_is_dispatch_object_p)(const void *);
OBJC_EXPORT void objc_register_dispatch_is_dispatch_object(bool(*func)(const void *)) {
    dispatch_is_dispatch_object_p = func;
}
bool dispatch_is_dispatch_object(const void *obj) {
    return dispatch_is_dispatch_object_p(obj);
}

// Copied from libobjc2/encoding2.c.
// TODO: Do these work correctly for our runtime? Maybe port Apple's NSGetSizeAndAlignment instead (if there is its source code).
// TODO: This doesn't work, why?
//#define alignof(type) __builtin_offsetof(struct { const char c; type member; }, member)
typedef const char *(*type_parser)(const char*, void*);
static int parse_array(const char **type, type_parser callback, void *context)
{
	// skip [
	(*type)++;
	int element_count = (int)strtol(*type, (char**)type, 10);
	*type = callback(*type, context);
	// skip ]
	(*type)++;
	return element_count;
}
static void parse_struct_or_union(const char **type, type_parser callback, void *context, char endchar)
{
	// Skip the ( and structure name
	do
	{
		(*type)++;
		// Opaque type has no =definition
		if (endchar == **type) { (*type)++; return; }
	} while('=' != **type);
	// Skip =
	(*type)++;

	while (**type != endchar)
	{
		// Structure elements sometimes have their names in front of each
		// element, as in {NSPoint="x"f"y"f} - We need to skip the type name
		// here.
		//
		// TODO: In a future version we should provide a callback that lets
		// users of this code get the field name
		if ('"'== **type)
		{

			do
			{
				(*type)++;
			} while ('"' != **type);
			// Skip the closing "
			(*type)++;
		}
		*type = callback(*type, context);
	}
	// skip }
	(*type)++;
}
static void parse_union(const char **type, type_parser callback, void *context)
{
	parse_struct_or_union(type, callback, context, ')');
}
static void parse_struct(const char **type, type_parser callback, void *context)
{
	parse_struct_or_union(type, callback, context, '}');
}
const char *objc_skip_type_qualifiers (const char *type)
{
	static const char *type_qualifiers = "rnNoORV";
	while('\0' != *type && strchr(type_qualifiers, *type))
	{
		type++;
	}
	return type;
}
inline static void round_up(size_t *v, size_t b)
{
	if (0 == b)
	{
		return;
	}

	if (*v % b)
	{
		*v += b - (*v % b);
	}
}
static const char *alignof_type(const char *type, size_t *align)
{
	type = objc_skip_type_qualifiers(type);
	switch (*type)
	{
		// For all primitive types, we return the maximum of the new alignment
		// and the old one
#define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
		case encodingChar:\
		{\
			*align = max((alignof(typeName) * 8), *align);\
			return type + 1;\
		}
#define NON_INTEGER_TYPES 1
#define SKIP_ID 1
#include "type_encoding_cases.h"
		case '@':
		{
			*align = max((alignof(id) * 8), *align);\
			if (*(type+1) == '?')
			{
				type++;
			}
			return type + 1;
		}
		case '?':
		case 'v': return type+1;
		case 'j':
		{
			type++;
			switch (*type)
			{
#define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
		case encodingChar:\
		{\
			*align = max((alignof(_Complex typeName) * 8), *align);\
			return type + 1;\
		}
#include "type_encoding_cases.h"
			}
		}
		case '{':
		{
			const char *t = type;
			parse_struct(&t, (type_parser)alignof_type, align);
			return t;
		}
		case '(':
		{
			const char *t = type;
			parse_union(&t, (type_parser)alignof_type, align);
			return t;
		}
		case '[':
		{
			const char *t = type;
			parse_array(&t, (type_parser)alignof_type, &align);
			return t;
		}
		case 'b':
		{
			// Consume the b
			type++;
			// Ignore the offset
			strtol(type, (char**)&type, 10);
			// Alignment of a bitfield is the alignment of the type that
			// contains it
			type = alignof_type(type, align);
			// Ignore the number of bits
			strtol(type, (char**)&type, 10);
			return type;
		}
		case '^':
		{
			*align = max((alignof(void*) * 8), *align);
			// All pointers look the same to me.
			size_t ignored = 0;
			// Skip the definition of the pointeee type.
			return alignof_type(type+1, &ignored);
		}
	}
	abort();
	return NULL;
}
OBJC_EXPORT size_t objc_alignof_type (const char *type)
{
	size_t align = 0;
	alignof_type(type, &align);
	return align / 8;
}
static const char *sizeof_type(const char *type, size_t *size);
static const char *sizeof_union_field(const char *type, size_t *size)
{
	size_t field_size = 0;
	const char *end = sizeof_type(type, &field_size);
	*size = max(*size, field_size);
	return end;
}
static const char *sizeof_type(const char *type, size_t *size)
{
	type = objc_skip_type_qualifiers(type);
	switch (*type)
	{
		// For all primitive types, we round up the current size to the
		// required alignment of the type, then add the size
#define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
		case encodingChar:\
		{\
			round_up(size, (alignof(typeName) * 8));\
			*size += (sizeof(typeName) * 8);\
			return type + 1;\
		}
#define SKIP_ID 1
#define NON_INTEGER_TYPES 1
#include "type_encoding_cases.h"
		case '@':
		{
			round_up(size, (alignof(id) * 8));
			*size += (sizeof(id) * 8);
			if (*(type+1) == '?')
			{
				type++;
			}
			return type + 1;
		}
		case '?':
		case 'v': return type+1;
		case 'j':
		{
			type++;
			switch (*type)
			{
#define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
		case encodingChar:\
		{\
			round_up(size, (alignof(_Complex typeName) * 8));\
			*size += (sizeof(_Complex typeName) * 8);\
			return type + 1;\
		}
#include "type_encoding_cases.h"
			}
		}
		case '{':
		{
			const char *t = type;
			parse_struct(&t, (type_parser)sizeof_type, size);
			size_t align = objc_alignof_type(type);
			round_up(size, align * 8);
			return t;
		}
		case '[':
		{
			const char *t = type;
			size_t element_size = 0;
			// FIXME: aligned size
			int element_count = parse_array(&t, (type_parser)sizeof_type, &element_size);
			(*size) += element_size * element_count;
			return t;
		}
		case '(':
		{
			const char *t = type;
			size_t union_size = 0;
			parse_union(&t, (type_parser)sizeof_union_field, &union_size);
			*size += union_size;
			return t;
		}
		case 'b':
		{
			// Consume the b
			type++;
			// Ignore the offset
			strtol(type, (char**)&type, 10);
			// Consume the element type
			type++;
			// Read the number of bits
			*size += strtol(type, (char**)&type, 10);
			return type;
		}
		case '^':
		{
			// All pointers look the same to me.
			*size += sizeof(void*) * 8;
			size_t ignored = 0;
			// Skip the definition of the pointeee type.
			return sizeof_type(type+1, &ignored);
		}
	}
	abort();
	return NULL;
}
OBJC_EXPORT const char *objc_skip_typespec(const char *type)
{
	size_t ignored = 0;
	return sizeof_type(type, &ignored);
}
OBJC_EXPORT size_t objc_sizeof_type(const char *type)
{
	size_t size = 0;
	sizeof_type(type, &size);
	return size / 8;
}
OBJC_EXPORT size_t objc_aligned_size(const char *type)
{
	size_t size  = objc_sizeof_type(type);
	size_t align = objc_alignof_type(type);
	return size + (size % align);
}

// Signatures copied from libobjc2/objc/runtime.h.
// TODO: Move this to something like `compat.mm`.
// TODO: From obj-abi.h on `objc_msgLookup` and related:
// "These are not callable C functions. Do not call them directly."
// Maybe just modify WinObjC so that it doesn't use this.
OBJC_EXPORT IMP objc_msg_lookup(id self, SEL _cmd) {
    return reinterpret_cast<IMP (*)(id, SEL)>(objc_msgLookup)(self, _cmd);
}
OBJC_EXPORT IMP objc_msg_lookup_super(struct objc_super *super, SEL _cmd) {
    return reinterpret_cast<IMP (*)(struct objc_super *, SEL)>(objc_msgLookupSuper2)(super, _cmd);
}

// Originals are in libobjc2/associate.m.
// TODO: Implement these correctly!
OBJC_EXPORT BOOL object_addMethod_np(id object, SEL name, IMP imp, const char *types)
{
	return class_addMethod(object, name, imp, types);
}
OBJC_EXPORT IMP object_replaceMethod_np(id object, SEL name, IMP imp, const char *types)
{
	return class_replaceMethod(object, name, imp, types);
}

// From libobjc2/NSBlocks.mm.
// TODO: Move to more appropriate place than `stubs.mm`.
extern "C" struct objc_class _NSConcreteGlobalBlock;
extern "C" struct objc_class _NSConcreteStackBlock;
extern "C" struct objc_class _NSConcreteMallocBlock;

static struct objc_class _NSConcreteGlobalBlockMeta;
static struct objc_class _NSConcreteStackBlockMeta;
static struct objc_class _NSConcreteMallocBlockMeta;

static struct objc_class _NSBlock;
static struct objc_class _NSBlockMeta;

static void createNSBlockSubclass(Class superclass, Class newClass,
		Class metaClass, const char *name)
{
	// We don't actually use the code from `libobjc2/NSBlocks.mm` here,
	// since it uses GNU's Objective-C ABI.

	objc_initializeClassPair(superclass, name, newClass, metaClass);
	objc_registerClassPair(newClass);
}

#define NEW_CLASS(super, sub) \
	createNSBlockSubclass((Class)super, (Class)&sub, (Class)&sub ## Meta, #sub)

OBJC_EXPORT BOOL objc_create_block_classes_as_subclasses_of(Class super) {
	if (_NSBlock.superclass != NULL) { return NO; }

	NEW_CLASS(super, _NSBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteStackBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteGlobalBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteMallocBlock);
	return YES;
}
