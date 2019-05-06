// ObjCHelper.hpp

#ifndef IPASIM_OBJC_HELPER_HPP
#define IPASIM_OBJC_HELPER_HPP

#include <llvm/ObjCMetadata/ObjCMachOBinary.h>
#include <llvm/Object/COFF.h>
#include <set>
#include <string>

namespace ipasim {

struct ObjCMethod {
  uint32_t RVA;
  std::string Name;

  bool operator<(const ObjCMethod &Other) const { return RVA < Other.RVA; }
};

class ObjCMethodScout {
public:
  static std::set<ObjCMethod>
  discoverMethods(const std::string &DLLPath,
                  llvm::object::COFFObjectFile *COFF);

private:
  std::set<ObjCMethod> Results;
  llvm::object::COFFObjectFile *COFF;
  std::unique_ptr<llvm::MemoryBuffer> MB;
  std::unique_ptr<llvm::object::MachOObjectFile> MachO;
  llvm::MachOMetadata Meta;

  ObjCMethodScout(llvm::object::COFFObjectFile *COFF,
                  std::unique_ptr<llvm::MemoryBuffer> &&MB,
                  std::unique_ptr<llvm::object::MachOObjectFile> &&MachO)
      : COFF(COFF), MB(std::move(MB)), MachO(std::move(MachO)),
        Meta(this->MachO.get()) {}

  void discoverMethods();
  template <typename ListTy> void findMethods(llvm::Expected<ListTy> &&List);
  void registerMethods(llvm::StringRef ElementName,
                       llvm::Expected<llvm::ObjCMethodList> &&Methods,
                       bool Static);
  template <typename ElementTy>
  static llvm::Expected<llvm::StringRef>
  getClassName(const ElementTy &Element) {
    return ObjCElement<ElementTy>::getClassName(Element);
  }
};

template <typename ElementTy> struct ObjCElement {
  static llvm::Expected<llvm::StringRef> getClassName(const ElementTy &Element);
};

} // namespace ipasim

// !defined(IPASIM_OBJC_HELPER_HPP)
#endif
