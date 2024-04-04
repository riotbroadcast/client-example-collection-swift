/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LiveKit
import UIKit

// enter your own LiveKit server url and token
let url = "wss://stephen-dzasntmt.livekit.cloud"
let token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjYyMjk2ODg2NjcsImlzcyI6IkFQSUF6Rm52aG5GenZFZSIsIm5iZiI6MTcxMjIyNTgzNywic3ViIjoidG9rZW44YSIsInZpZGVvIjp7ImNhblB1Ymxpc2giOnRydWUsImNhblB1Ymxpc2hEYXRhIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWUsInJvb20iOiJyaW90Iiwicm9vbUpvaW4iOnRydWV9fQ.rerkpRFuRffTFkHVRduFXkhCvayt-VtdN0YF3mmhyVo"

fileprivate let kIceServerUrl = "turn:turn.riotbroadcast.com:3478"
fileprivate let kIceServerUsername = "riotbroadcast"
fileprivate let kIceServerCredential = "wormy12345"

class RoomViewController: UIViewController {
    private var _plusButtonView: UIButton!
    private var _minusButtonView: UIButton!
    private var _delayLabelView: UILabel!
    private var _silenceLabelView: UILabel!

    private lazy var room: Room = .init(delegate: self)

    private lazy var collectionView: UICollectionView = {
        print("creating UICollectionView...")
        let r = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        r.backgroundColor = .black
        r.register(ParticipantCell.self, forCellWithReuseIdentifier: ParticipantCell.reuseIdentifier)
        r.delegate = self
        r.dataSource = self
        r.alwaysBounceVertical = true
        r.contentInsetAdjustmentBehavior = .never
        return r
    }()

    private var remoteParticipants = [RemoteParticipant]()

    private var cellReference = NSHashTable<ParticipantCell>.weakObjects()
    private var timer: Timer?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        // todo ?
        // timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
        //     guard let self else { return }
        //     self.reComputeVideoViewEnabled()
        // })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    private func updateDelayLabel() {
        let delay = self.room.riotDelay
        _delayLabelView.text = "Delay: \(delay)s"
        self.view.setNeedsLayout()
    }

    private func updateSilenceLabel() {
        var value = ""
        if let silenceRemaining = room.riotSilenceRemaining {
            value = "\(silenceRemaining)s"
        } else {
            value = "-"
        }
        let oldText = _silenceLabelView.text
        _silenceLabelView.text = "Silence: \(value)"
        if oldText != _silenceLabelView.text {
            self.view.setNeedsLayout()
        }
    }

    private func changeDelay(_ delta: TimeInterval) {
        let oldDelay = self.room.riotDelay
        self.room.riotDelay = max(0, oldDelay + delta)
        updateDelayLabel()
    }

    @objc private func handlePlus(_ sender: AnyObject) {
        changeDelay(+1.0)
    }

    @objc private func handleMinus(_ sender: AnyObject) {
        changeDelay(-1.0)
     }

    override func loadView() {
        super.loadView()
        view.addSubview(collectionView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            await updateNavigationBar()
        }

        _plusButtonView = UIButton(type: .roundedRect)
        _plusButtonView.backgroundColor = .green
        _plusButtonView.setTitle("+", for: .normal)
        _plusButtonView.addTarget(self, action: #selector(handlePlus(_:)), for: .touchUpInside)
        self.view.addSubview(_plusButtonView)

        _minusButtonView = UIButton(type: .roundedRect)
        _minusButtonView.backgroundColor = .orange
        _minusButtonView.setTitle("-", for: .normal)
        _minusButtonView.addTarget(self, action: #selector(handleMinus(_:)), for: .touchUpInside)
        self.view.addSubview(_minusButtonView)

        _delayLabelView = UILabel(frame: .zero)
        _delayLabelView.backgroundColor = .darkGray
        _delayLabelView.textColor = .white
        self.view.addSubview(_delayLabelView)

        _silenceLabelView = UILabel(frame: .zero)
        _silenceLabelView.backgroundColor = .darkGray
        _silenceLabelView.textColor = .white
        self.view.addSubview(_silenceLabelView)

        updateDelayLabel()
        updateSilenceLabel()

        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            self.updateSilenceLabel()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        collectionView.frame = view.bounds
        collectionView.collectionViewLayout.invalidateLayout()

        var plusButtonViewFrame = CGRect.zero
        plusButtonViewFrame.size = CGSize(width: 100, height: 50)
        plusButtonViewFrame.origin.x = 50
        plusButtonViewFrame.origin.y = view.bounds.maxY - 100 - plusButtonViewFrame.size.height
        _plusButtonView.frame = plusButtonViewFrame

        var minusButtonViewFrame = plusButtonViewFrame
        minusButtonViewFrame.origin.x = view.bounds.maxX - plusButtonViewFrame.origin.x - minusButtonViewFrame.size.width
        _minusButtonView.frame = minusButtonViewFrame

        var delayLabelViewFrame = CGRect.zero
        delayLabelViewFrame.size = _delayLabelView.intrinsicContentSize
        delayLabelViewFrame.origin.x = plusButtonViewFrame.origin.x
        delayLabelViewFrame.origin.y = plusButtonViewFrame.origin.y - 20 - delayLabelViewFrame.size.height
        _delayLabelView.frame = delayLabelViewFrame

        var silenceLabelViewFrame = CGRect.zero
        silenceLabelViewFrame.size = _silenceLabelView.intrinsicContentSize
        silenceLabelViewFrame.origin.x = view.bounds.maxX - delayLabelViewFrame.origin.x - silenceLabelViewFrame.size.width
        silenceLabelViewFrame.origin.y = plusButtonViewFrame.origin.y - 20 - silenceLabelViewFrame.size.height
        _silenceLabelView.frame = silenceLabelViewFrame
    }

    @MainActor
    private func setParticipants() async {
        remoteParticipants = Array(room.remoteParticipants.values)
        collectionView.reloadData()
        await updateNavigationBar()
    }

    @MainActor
    private func updateNavigationBar() async {
        navigationItem.title = nil
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil

        switch room.connectionState {
        case .disconnected:
            navigationItem.title = "Disconnected"
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Connect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapConnect(sender:)))
        case .connecting:
            navigationItem.title = "Connecting..."
        case .reconnecting:
            navigationItem.title = "Re-Connecting..."
        case .connected:
            navigationItem.title = "\(room.name ?? "No name") (\(room.remoteParticipants.count))"
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Disconnect",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(onTapDisconnect(sender:)))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Shuffle",
                                                                style: .plain,
                                                                target: self,
                                                                action: #selector(onTapShuffle(sender:)))
        }
    }

    @MainActor
    @objc func onTapConnect(sender _: UIBarButtonItem) {
        navigationItem.leftBarButtonItem?.isEnabled = false

        //let connectOptions = ConnectOptions(
        //    iceServers: [
        //        IceServer(
        //            urls: [kIceServerUrl],
        //            username: kIceServerUsername,
        //            credential: kIceServerCredential)])

        let roomOptions = RoomOptions(
            adaptiveStream: true,
            dynacast: true
        )

        Task {
            do {
                try await room.connect(url: url, token: token, roomOptions: roomOptions)
                print("connected to server version: \(String(describing: room.serverVersion))")
                await setParticipants()
            } catch {
                print("failed to connect with error: \(error)")
                await updateNavigationBar()
            }
        }
    }

    @MainActor
    @objc func onTapDisconnect(sender _: UIBarButtonItem) {
        navigationItem.leftBarButtonItem?.isEnabled = false

        Task {
            await room.disconnect()
            await updateNavigationBar()
        }
    }

    @MainActor
    @objc func onTapShuffle(sender _: UIBarButtonItem) {
        remoteParticipants.shuffle()
        collectionView.reloadData()
    }
}

extension RoomViewController: RoomDelegate {
    func roomDidConnect(_ room: Room) {
        NSLog("%@", "[RoomDelegate] roomDidConnect")
    }

    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        NSLog("%@", "[RoomDelegate] room didDisconnectWithError")
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        NSLog("%@", "[RoomDelegate] room didUpdateConnectionState: \(oldConnectionState) -> \(connectionState)")

        Task { @MainActor in

            if case .disconnected = connectionState {
                remoteParticipants = []
                collectionView.reloadData()
            }

            await updateNavigationBar()
        }
    }

    func room(_: Room, participantDidConnect _: RemoteParticipant) {
        print("participant did join")
        Task { @MainActor in
            await setParticipants()
        }
    }

    @MainActor
    func room(_: Room, participantDidDisconnect _: RemoteParticipant) {
        print("participant did leave")
        Task { @MainActor in
            await setParticipants()
        }
    }

    func room(_ room: Room, participant: Participant, didUpdateConnectionQuality quality: ConnectionQuality) {
        NSLog("%@", "[RoomDelegate] room didUpdateConnectionQuality: \(quality)")
    }
}

extension RoomViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        print("sizeForItemAt...")

        let columns: CGFloat = 2
        let size = collectionView.bounds.width / columns
        return CGSize(width: size, height: size)
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets {
        .zero
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        0
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("didSelectItemAt: \(indexPath)")
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    func reComputeVideoViewEnabled() {
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? ParticipantCell }
        let offScreenCells = cellReference.allObjects.filter { !visibleCells.contains($0) }

        for cell in visibleCells.filter({ !$0.videoView.isEnabled }) {
            print("setting cell#\(cell.cellId) to true")
            cell.videoView.isEnabled = true
        }

        for cell in offScreenCells.filter(\.videoView.isEnabled) {
            print("setting cell#\(cell.cellId) to false")
            cell.videoView.isEnabled = false
        }
    }
}

extension RoomViewController: UICollectionViewDataSource {
    public func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        // total number of participants to show (including local participant)
        print("numberOfItemsInSection...")
        return remoteParticipants.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ParticipantCell.reuseIdentifier,
                                                      for: indexPath)

        if let cell = cell as? ParticipantCell {
            // keep weak reference to cell
            cellReference.add(cell)

            if indexPath.row < remoteParticipants.count {
                let participant = remoteParticipants[indexPath.row]
                cell.participant = participant
            }
        }

        return cell
    }
}
