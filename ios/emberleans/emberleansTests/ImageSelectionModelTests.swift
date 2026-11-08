import Foundation
import PhotosUI
import SwiftUI
import Testing
@testable import emberleans

@MainActor
@Suite("ImageSelectionModel")
struct ImageSelectionModelTests {
    private func makeModel(
        camera: StubCamera = StubCamera(),
        loader: StubPhotoLoader = StubPhotoLoader(.data(nil))
    ) -> ImageSelectionModel {
        ImageSelectionModel(camera: camera, photoLoader: loader)
    }

    // MARK: Sheet

    @Test func beginPresentsSourceSheetWithTitle() {
        let model = makeModel()
        model.begin(title: "Escolher outra imagem")
        #expect(model.presentation == .sourceSheet)
        #expect(model.sheetTitle == "Escolher outra imagem")
    }

    @Test func cancellingTheSheetPresentsNothing() async {
        let model = makeModel()
        model.begin()
        model.cancelSourceSheet()
        await model.sourceSheetDidDismiss()
        #expect(model.presentation == nil)
        #expect(model.alert == nil)
    }

    @Test func choosingPhotoLibraryPresentsPickerAfterSheetCloses() async {
        let model = makeModel()
        model.begin()
        model.choose(.photoLibrary)
        #expect(model.presentation == nil)
        await model.sourceSheetDidDismiss()
        #expect(model.presentation == .photoLibrary)
    }

    // MARK: Câmera

    @Test func authorizedCameraIsPresented() async {
        let model = makeModel(camera: StubCamera(status: .authorized))
        model.begin()
        model.choose(.camera)
        await model.sourceSheetDidDismiss()
        #expect(model.presentation == .camera)
    }

    @Test func unavailableCameraShowsAlert() async {
        let model = makeModel(camera: StubCamera(available: false))
        model.begin()
        model.choose(.camera)
        await model.sourceSheetDidDismiss()
        #expect(model.presentation == nil)
        #expect(model.alert == .cameraUnavailable)
    }

    @Test(arguments: [CameraAuthorization.denied, .restricted])
    func deniedCameraShowsPermissionAlert(status: CameraAuthorization) async {
        let model = makeModel(camera: StubCamera(status: status))
        await model.openCamera()
        #expect(model.presentation == nil)
        #expect(model.alert == .cameraPermissionDenied)
    }

    @Test(arguments: [true, false])
    func undeterminedCameraRequestsAccess(granted: Bool) async {
        let camera = StubCamera(status: .notDetermined, grantOnRequest: granted)
        let model = makeModel(camera: camera)
        await model.openCamera()
        #expect(camera.requestCount == 1)
        #expect(model.presentation == (granted ? .camera : nil))
        #expect(model.alert == (granted ? nil : .cameraPermissionDenied))
    }

    @Test func capturedPhotoCompletesSelection() throws {
        let model = makeModel()
        model.cameraDidCapture(Fixtures.image())
        #expect(model.presentation == nil)
        let completion = try #require(model.completion)
        guard case .image(let image) = completion.outcome else {
            Issue.record("esperava uma imagem")
            return
        }
        #expect(image.source == .camera)
    }

    @Test func missingCapturedPhotoShowsAlert() {
        let model = makeModel()
        model.cameraDidCapture(nil)
        #expect(model.completion == nil)
        #expect(model.alert == .captureFailed)
    }

    @Test func cancellingCameraDoesNotComplete() async {
        let model = makeModel()
        await model.openCamera()
        model.cameraDidCancel()
        #expect(model.presentation == nil)
        #expect(model.completion == nil)
    }

    // MARK: Fototeca

    @Test func validLibraryImageCompletesSelection() async throws {
        let data = try #require(Fixtures.image().pngData())
        let model = makeModel(loader: StubPhotoLoader(.data(data)))
        await model.loadPhotoLibraryItem(PhotosPickerItem(itemIdentifier: "test"))
        let completion = try #require(model.completion)
        guard case .image(let image) = completion.outcome else {
            Issue.record("esperava uma imagem")
            return
        }
        #expect(image.source == .photoLibrary)
        #expect(!model.isLoadingLibraryImage)
        #expect(model.photoPickerItem == nil)
    }

    @Test func undecodableLibraryDataIsInvalidImage() async throws {
        let model = makeModel(loader: StubPhotoLoader(.data(Data("não é imagem".utf8))))
        await model.loadPhotoLibraryItem(PhotosPickerItem(itemIdentifier: "test"))
        let completion = try #require(model.completion)
        #expect(completion.outcome == .invalidImage)
    }

    @Test func libraryWithoutDataShowsAlert() async {
        let model = makeModel(loader: StubPhotoLoader(.data(nil)))
        await model.loadPhotoLibraryItem(PhotosPickerItem(itemIdentifier: "test"))
        #expect(model.completion == nil)
        #expect(model.alert == .libraryLoadFailed)
        #expect(!model.isLoadingLibraryImage)
    }

    @Test func libraryLoadErrorShowsAlert() async {
        let model = makeModel(loader: StubPhotoLoader(.failure))
        await model.loadPhotoLibraryItem(PhotosPickerItem(itemIdentifier: "test"))
        #expect(model.completion == nil)
        #expect(model.alert == .libraryLoadFailed)
        #expect(!model.isLoadingLibraryImage)
    }

    @Test func eachCompletionIsDistinct() {
        let model = makeModel()
        model.cameraDidCapture(Fixtures.image())
        let first = model.completion
        model.cameraDidCapture(Fixtures.image())
        #expect(model.completion != first)
    }
}
